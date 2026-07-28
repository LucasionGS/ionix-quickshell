pragma Singleton

// Media facade.
//
// Prefers a real MPRIS player (Toxen exposes one, as does anything else you'd
// play music with). Falls back to polling `toxen-mini` only when MPRIS has
// nothing AND the binary actually exists — the `which` probe means machines
// without Toxen never spawn a poll loop, which is the flaw in the waybar script
// this replaces.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.config

Singleton {
    id: root

    readonly property string backend: Config.media.backend
    readonly property bool mprisAllowed: backend === "auto" || backend === "mpris"
    readonly property bool fallbackAllowed: backend === "auto" || backend === "toxen-mini"

    // Manual override from the popout's player selector; cleared when it vanishes.
    property MprisPlayer selected: null

    readonly property var players: Mpris.players.values.filter(p => p.canControl)

    readonly property MprisPlayer player: {
        if (!root.mprisAllowed)
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

    // ── Fallback state ──────────────────────────────────────────────────────
    property bool fallbackAvailable: false
    property string fallbackStatus: ""
    property string fallbackTitle: ""
    property string fallbackArtist: ""

    readonly property bool usingFallback: !root.player && root.fallbackAllowed && root.fallbackAvailable && root.fallbackStatus !== ""

    // ── Unified interface ───────────────────────────────────────────────────
    readonly property bool active: !!root.player || root.usingFallback
    readonly property bool playing: root.player ? root.player.isPlaying : root.fallbackStatus === "playing"
    readonly property string title: root.player ? (root.player.trackTitle ?? "") : root.fallbackTitle
    readonly property string artist: root.player ? (root.player.trackArtist ?? "") : root.fallbackArtist
    readonly property string album: root.player?.trackAlbum ?? ""
    readonly property string artUrl: root.player?.trackArtUrl ?? ""
    readonly property string identity: root.player ? (root.player.identity ?? "Player") : "Toxen"

    readonly property bool canSeek: root.player?.canSeek ?? false
    readonly property real position: root.player?.position ?? 0
    readonly property real length: root.player?.length ?? 0
    readonly property bool canSetVolume: root.player?.volumeSupported ?? false

    function toggle() {
        if (root.player)
            root.player.togglePlaying();
        else if (root.usingFallback)
            run(["toxen-mini", "-s", "toggle"]);
    }

    function next() {
        if (root.player)
            root.player.next();
        else if (root.usingFallback)
            run(["toxen-mini", "-s", "next"]);
    }

    function previous() {
        if (root.player)
            root.player.previous();
        else if (root.usingFallback)
            run(["toxen-mini", "-s", "prev"]);
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

    function run(cmd) {
        Quickshell.execDetached(cmd);
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

    // ── Fallback plumbing ───────────────────────────────────────────────────

    Component.onCompleted: {
        if (root.fallbackAllowed)
            probe.running = true;
    }

    Process {
        id: probe
        command: ["which", "toxen-mini"]
        onExited: code => root.fallbackAvailable = (code === 0)
    }

    // Only ticks when MPRIS gave us nothing and toxen-mini exists.
    Timer {
        running: root.fallbackAvailable && root.fallbackAllowed && !root.player
        interval: 2000
        repeat: true
        triggeredOnStart: true
        onTriggered: statusProc.running = true
    }

    Process {
        id: statusProc
        command: ["toxen-mini", "-s", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.fallbackStatus = text.trim();
                if (root.fallbackStatus !== "") {
                    titleProc.running = true;
                    artistProc.running = true;
                } else {
                    root.fallbackTitle = "";
                    root.fallbackArtist = "";
                }
            }
        }
    }

    Process {
        id: titleProc
        command: ["toxen-mini", "-s", "title"]
        stdout: StdioCollector {
            onStreamFinished: root.fallbackTitle = text.trim()
        }
    }

    Process {
        id: artistProc
        command: ["toxen-mini", "-s", "artist"]
        stdout: StdioCollector {
            onStreamFinished: root.fallbackArtist = text.trim()
        }
    }
}
