pragma Singleton

// The countdown timer behind the clock's right-click panel.
//
// A singleton rather than state in the popout, because the timer has to outlive
// the panel: closing it must not stop the count, and every monitor's clock pill
// shows the same one. Called Countdown and not Timer so it never shadows
// QtQuick's Timer in a file that imports both.
//
// Time is kept as an end timestamp, not a counter decremented by the tick. A
// QML Timer drifts under load and stops altogether while the machine sleeps; a
// deadline compared against the wall clock comes back right after either.
//
// When it expires it rings until dismissed: pw-play plays the alarm sound, and
// its exit starts a short gap before the next one. pw-play ships with pipewire,
// which the shell already depends on, so the beep needs no audio stack of its own.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    // idle → running ⇄ paused → ringing → idle
    property string phase: "idle"
    readonly property bool running: root.phase === "running"
    readonly property bool paused: root.phase === "paused"
    readonly property bool ringing: root.phase === "ringing"
    // Anything the clock pill should show.
    readonly property bool active: root.phase !== "idle"

    // What the arrows edit, in seconds. Kept after a run so the next one starts
    // from the same length.
    property int duration: 5 * 60

    property double endMs: 0
    // Frozen remainder while paused.
    property double pausedMs: 0
    property double nowMs: Date.now()

    readonly property int remaining: {
        if (root.running)
            return Math.max(0, Math.ceil((root.endMs - root.nowMs) / 1000));
        if (root.paused)
            return Math.ceil(root.pausedMs / 1000);
        return root.ringing ? 0 : root.duration;
    }

    readonly property var cfg: Config.clock.timer ?? ({})
    readonly property string sound: root.cfg.sound ?? "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"
    readonly property int beepGap: root.cfg.beepGap ?? 400
    readonly property int maxDuration: 99 * 3600 + 59 * 60 + 59

    function setDuration(seconds) {
        root.duration = Math.max(0, Math.min(root.maxDuration, Math.round(seconds)));
    }

    // Steps one field of H:MM:SS, wrapping within the field instead of carrying
    // into the next, the way a kitchen timer's digit wheels behave. `unit` is
    // 3600, 60 or 1.
    function step(unit, delta) {
        const h = Math.floor(root.duration / 3600);
        const m = Math.floor(root.duration / 60) % 60;
        const s = root.duration % 60;
        const wrap = (v, n) => ((v + delta) % n + n) % n;
        if (unit === 3600)
            root.setDuration(wrap(h, 100) * 3600 + m * 60 + s);
        else if (unit === 60)
            root.setDuration(h * 3600 + wrap(m, 60) * 60 + s);
        else
            root.setDuration(h * 3600 + m * 60 + wrap(s, 60));
    }

    function start(seconds) {
        if (seconds !== undefined)
            root.setDuration(seconds);
        if (root.duration <= 0)
            return;
        root.stopRinging();
        root.nowMs = Date.now();
        root.endMs = root.nowMs + root.duration * 1000;
        root.phase = "running";
    }

    function pause() {
        if (!root.running)
            return;
        root.pausedMs = Math.max(0, root.endMs - Date.now());
        root.phase = "paused";
    }

    function resume() {
        if (!root.paused)
            return;
        root.nowMs = Date.now();
        root.endMs = root.nowMs + root.pausedMs;
        root.phase = "running";
    }

    function toggle() {
        if (root.running)
            root.pause();
        else if (root.paused)
            root.resume();
        else
            root.start();
    }

    // Back to idle from anywhere, ringing included.
    function reset() {
        root.stopRinging();
        root.phase = "idle";
    }

    function dismiss() {
        if (root.ringing)
            root.reset();
    }

    function stopRinging() {
        gap.stop();
        beep.running = false;
    }

    // 4:05, 12:00, 1:02:03 — hours only once there are any.
    function format(total) {
        const h = Math.floor(total / 3600);
        const m = Math.floor(total / 60) % 60;
        const s = total % 60;
        const pad = n => String(n).padStart(2, "0");
        return h > 0 ? `${h}:${pad(m)}:${pad(s)}` : `${m}:${pad(s)}`;
    }

    // Four ticks a second so the display never visibly skips a digit when the
    // tick and the second boundary drift against each other. Only while running.
    Timer {
        interval: 250
        repeat: true
        running: root.running
        triggeredOnStart: true
        onTriggered: {
            root.nowMs = Date.now();
            if (root.nowMs >= root.endMs) {
                root.phase = "ringing";
                beep.running = true;
            }
        }
    }

    Process {
        id: beep
        command: ["pw-play", root.sound]
        // A missing sound file makes pw-play exit at once; the gap still spaces
        // the retries so a broken path can't spin a process a millisecond.
        onExited: {
            if (root.ringing)
                gap.restart();
        }
    }

    Timer {
        id: gap
        interval: Math.max(100, root.beepGap)
        onTriggered: {
            if (root.ringing)
                beep.running = true;
        }
    }
}
