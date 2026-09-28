pragma Singleton

// Media facade.
//
// Everything comes from MPRIS, so any music player or browser that publishes
// the standard interface works with no per-player support in the shell. When
// several are running, `media.preferred` picks one by identity or D-Bus name,
// otherwise whichever is playing wins and the popout's selector can override.

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.config

Singleton {
    id: root

    readonly property string backend: Config.media.backend
    readonly property bool enabled: backend !== "off"

    // Manual override from the popout's player selector; cleared when it vanishes.
    property MprisPlayer selected: null

    readonly property var players: Mpris.players.values.filter(p => p.canControl)

    readonly property MprisPlayer player: {
        if (!root.enabled)
            return null;
        const list = root.players;
        if (list.length === 0)
            return null;
        if (root.selected && list.includes(root.selected))
            return root.selected;
        // Prefer the configured player, then anything currently playing.
        const want = (Config.media.preferred ?? "").toLowerCase();
        if (want !== "") {
            const match = list.find(p => (p.identity ?? "").toLowerCase().includes(want) || (p.dbusName ?? "").toLowerCase().includes(want));
            if (match)
                return match;
        }
        return list.find(p => p.isPlaying) ?? list[0];
    }

    // ── Unified interface ───────────────────────────────────────────────────
    readonly property bool active: !!root.player
    readonly property bool playing: root.player?.isPlaying ?? false
    readonly property string title: root.player?.trackTitle ?? ""
    readonly property string artist: root.player?.trackArtist ?? ""
    readonly property string album: root.player?.trackAlbum ?? ""
    readonly property string artUrl: root.player?.trackArtUrl ?? ""
    readonly property string identity: root.player ? (root.player.identity ?? "Player") : "Player"

    readonly property bool canSeek: root.player?.canSeek ?? false
    readonly property real position: root.player?.position ?? 0
    readonly property real length: root.player?.length ?? 0
    readonly property bool canSetVolume: root.player?.volumeSupported ?? false

    function toggle() {
        root.player?.togglePlaying();
    }

    function next() {
        root.player?.next();
    }

    function previous() {
        root.player?.previous();
    }

    function seek(seconds) {
        const p = root.player;
        if (!p?.canSeek)
            return;
        // Offset from the player's own value, not `root.position` — that one is
        // only as fresh as the last tick of the timer below.
        p.position = Math.max(0, Math.min(root.length, p.position + seconds));
    }

    function seekTo(fraction) {
        if (root.player?.canSeek && root.length > 0)
            root.player.position = root.length * Math.max(0, Math.min(1, fraction));
    }

    function setVolume(v) {
        if (root.player?.volumeSupported)
            root.player.volume = Math.max(0, Math.min(1, v));
    }

    function formatTime(seconds) {
        if (!isFinite(seconds) || seconds < 0)
            return "0:00";
        const total = Math.floor(seconds);
        const m = Math.floor(total / 60);
        const s = total % 60;
        return `${m}:${s < 10 ? "0" : ""}${s}`;
    }

    // ── Position ────────────────────────────────────────────────────────────

    // Reading MprisPlayer.position runs the player's own clock forward, but
    // Quickshell only emits positionChanged when D-Bus reports a jump — so a QML
    // binding on it latches onto whatever the last seek reported and never moves
    // again. Emitting the signal ourselves is what re-runs those bindings; there
    // is no property that ticks on its own.
    //
    // This runs whenever something is playing rather than only while the popout is
    // open, because a stale `position` would also shift the wheel-scrub in the bar.
    // A paused player needs no tick: its position genuinely isn't moving, and a
    // seek from outside the shell emits positionChanged by itself.
    Timer {
        running: !!root.player && root.playing
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.player?.positionChanged()
    }
}
