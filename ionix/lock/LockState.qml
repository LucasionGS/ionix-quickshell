pragma Singleton

// Everything the lock screen knows that isn't drawing: what has been typed, the
// two PAM conversations, and whether the screensaver is up.
//
// One of these for the whole lock rather than one per monitor. Every screen's
// surface draws from it and forwards its keys into it, so it does not matter
// which output the compositor gave keyboard focus to — the dots appear on all
// of them.
//
// The password is kept in `buffer`, not in a TextInput. A TextInput per screen
// would mean one copy per screen and a question of which is authoritative; a
// string here is one copy, cleared on every attempt.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import qs.config

Singleton {
    id: root

    // ── Greeter mode ────────────────────────────────────────────────────────
    //
    // The same screen serves as a login greeter under cage (greeter.qml sets
    // IONIX_GREETER=1 through bin/ionix-greeter). The differences: there is a
    // username to type as well as a password, the password is checked by greetd
    // (GreeterBackend.qml) rather than by our own PamContext, and success starts
    // a session instead of releasing a lock.
    //
    // IONIX_GREETER_DRY=1 is for trying it without greetd: our own PAM stack
    // checks the password for `username` and nothing is launched.
    readonly property bool greeter: Quickshell.env("IONIX_GREETER") === "1"
    readonly property bool greeterDry: Quickshell.env("IONIX_GREETER_DRY") === "1"
    // The account being logged into. Prefilled from the last login; editing it
    // is the card's job (LockCard), and `usernameEditing` says the text field
    // rather than the password buffer is where typing goes.
    property string username: ""
    property bool usernameEditing: false
    // Set by the backend: the greeter is waiting on a login (create_session done).
    property bool greeterBusy: false

    property string buffer: ""
    // idle | checking | failed
    property string phase: "idle"
    property string message: ""
    property int failures: 0
    // Latches true on success; the surfaces animate out on it and lock.qml
    // releases the lock after them.
    property bool unlocked: false

    signal failed
    // Greeter: the password is ready for greetd (GreeterBackend listens).
    signal submitted

    // ── Screensaver ─────────────────────────────────────────────────────────
    //
    // `awake` is the password card being up. Any input sets it and restarts the
    // countdown; the countdown ending clears it. It is also held true while a
    // check is running or just failed, so the card never fades out from under
    // an error message.
    property bool awake: true
    // A login screen that blanks under someone typing their username is worse
    // than one that stays up.
    readonly property int idleAfter: root.greeter ? 0 : Math.max(0, Config.lock.screensaver?.after ?? 15)

    function poke() {
        root.awake = true;
        if (root.idleAfter > 0)
            idleTimer.restart();
    }

    Timer {
        id: idleTimer
        interval: Math.max(1, root.idleAfter) * 1000
        running: root.idleAfter > 0
        onTriggered: {
            // Mid-typing is not idle, and neither is an attempt in flight.
            if (root.buffer !== "" || root.phase === "checking")
                restart();
            else
                root.awake = false;
        }
    }

    // ── Typing ──────────────────────────────────────────────────────────────

    // Called by every surface with its key events. Returns whether the event
    // was used, so the caller can accept it.
    function key(event) {
        const wasAwake = root.awake;
        root.poke();
        capsProbe.check();

        if (root.unlocked || root.phase === "checking")
            return true;

        const ctrl = (event.modifiers & Qt.ControlModifier) && !(event.modifiers & Qt.AltModifier);

        switch (event.key) {
        case Qt.Key_Escape:
            root.buffer = "";
            root.clearFailure();
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            root.submit();
            return true;
        case Qt.Key_Tab:
        case Qt.Key_Backtab:
        case Qt.Key_Up:
            if (root.greeter) {
                root.usernameEditing = true;
                return true;
            }
            break;
        case Qt.Key_Backspace:
            root.buffer = ctrl ? "" : root.buffer.slice(0, -1);
            return true;
        }

        if (ctrl) {
            if (event.key === Qt.Key_U)
                root.buffer = "";
            return true;
        }

        // Printable text only. Checking the text rather than the key keeps
        // AltGr combinations working (a Danish @ is AltGr+2), which a
        // modifier test would throw away.
        const text = event.text;
        if (text.length > 0 && !/[\u0000-\u001f\u007f]/.test(text)) {
            root.buffer += text;
            root.clearFailure();
            return true;
        }

        // A bare modifier or a function key: its only job was waking the card.
        return !wasAwake;
    }

    function clearFailure() {
        if (root.phase === "failed") {
            root.phase = "idle";
            root.message = "";
        }
    }

    function submit() {
        if (root.unlocked || root.phase === "checking" || root.buffer === "")
            return;
        if (root.greeter && root.username.trim() === "") {
            root.usernameEditing = true;
            return;
        }
        root.phase = "checking";
        root.message = "";
        if (root.greeter && !root.greeterDry)
            root.submitted();
        else
            password.active = true;
    }

    function succeed() {
        if (root.unlocked)
            return;
        root.unlocked = true;
        root.buffer = "";
        password.active = false;
        finger.active = false;
    }

    function fail(text) {
        // PamContext can report one attempt twice — error() and then
        // completed() — and only the first may count.
        if (root.phase !== "checking")
            return;
        root.buffer = "";
        root.failures++;
        root.phase = "failed";
        root.message = text;
        root.poke();
        root.failed();
    }

    // ── Password ────────────────────────────────────────────────────────────

    readonly property string pamDir: Quickshell.shellDir + "/lock/pam"

    PamContext {
        id: password
        configDirectory: root.pamDir
        config: "password"
        // Only the greeter dry run names someone; everywhere else it is the
        // session's own user, which is PamContext's default.
        user: root.greeter && root.greeterDry ? root.username.trim() : ""

        // pam_unix asks exactly once. Answering from the change handler rather
        // than feeding the password in up front means nothing holds it beyond
        // the buffer, which submit()'s callers clear on every outcome.
        onResponseRequiredChanged: {
            if (responseRequired && active)
                respond(root.buffer);
        }

        onCompleted: result => {
            if (result === PamResult.Success)
                root.succeed();
            else if (result === PamResult.MaxTries)
                root.fail("Too many attempts — try again");
            else
                root.fail(root.failures > 0 ? `Wrong password (${root.failures + 1})` : "Wrong password");
        }

        onError: error => {
            console.warn(`[ionix-lock] password check: ${PamError.toString(error)}`);
            root.fail("Could not check the password");
        }
    }

    // ── Fingerprint ─────────────────────────────────────────────────────────
    //
    // Runs alongside the password, never in front of it — the same race hyprlock
    // drives over D-Bus, reached here through pam_fprintd instead so there is one
    // mechanism for both. pam_fprintd tells us nothing about the hardware before
    // it is asked, so whether a reader exists is learned from the first attempt:
    // if it prompts, there is one; if it fails without prompting, there isn't (or
    // nothing is enrolled) and it is never started again.

    // In the greeter it is greetd's PAM stack that listens (GreeterBackend feeds
    // the state below), so this context stays off.
    readonly property bool fingerprintWanted: !root.greeter && Config.lock.fingerprint !== false && fprintModule.exists
    property bool fingerprintAvailable: false
    property bool fingerprintScanning: false
    property string fingerprintMessage: ""
    // Set once pam_fprintd has prompted in the current round.
    property bool promptedThisRound: false

    PamContext {
        id: finger
        configDirectory: root.pamDir
        config: "fingerprint"

        onMessageChanged: {
            if (!active || message === "")
                return;
            root.promptedThisRound = true;
            root.fingerprintAvailable = true;
            if (messageIsError) {
                // "Failed to match fingerprint" — surfaced, but not as a failed
                // password: the field and its dots stay as they are.
                root.fingerprintMessage = message;
                root.poke();
            } else {
                root.fingerprintScanning = true;
            }
        }

        onCompleted: result => {
            root.fingerprintScanning = false;
            if (result === PamResult.Success) {
                root.succeed();
                return;
            }
            // Prompted and then timed out or ran out of tries: go again. Never
            // prompted: nothing to scan with, stop here.
            if (root.promptedThisRound && !root.unlocked)
                fingerRestart.restart();
        }

        onError: error => {
            root.fingerprintScanning = false;
            console.info(`[ionix-lock] fingerprint: ${PamError.toString(error)}`);
        }
    }

    // The module probe below can land after Component.onCompleted, so the
    // first attempt starts on whichever comes second.
    onFingerprintWantedChanged: root.startFingerprint()

    function startFingerprint() {
        if (!root.fingerprintWanted || root.unlocked || finger.active)
            return;
        root.promptedThisRound = false;
        finger.active = true;
    }

    Timer {
        id: fingerRestart
        interval: 1200
        onTriggered: {
            root.fingerprintMessage = "";
            root.startFingerprint();
        }
    }

    // The PAM module comes with fprintd, which Ionix ships everywhere, but the
    // shell also runs on machines that don't have it; asking PAM to load a module
    // that isn't there logs an error on every attempt.
    FileView {
        id: fprintModule
        property bool exists: false
        path: "/usr/lib/security/pam_fprintd.so"
        printErrors: false
        blockLoading: true
        // Only existence matters; the loaded bytes are never read.
        onLoaded: exists = true
        onLoadFailed: exists = false
    }

    // ── Caps Lock ───────────────────────────────────────────────────────────
    //
    // Key events carry no Caps Lock state, so read the keyboard LEDs instead —
    // world-readable, and one tiny read per burst of typing.
    property bool capsLock: false

    Process {
        id: capsProbe
        command: ["sh", "-c", "cat /sys/class/leds/*::capslock/brightness 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.capsLock = this.text.split("\n").some(l => parseInt(l) > 0)
        }

        function check() {
            capsDebounce.restart();
        }
    }

    Timer {
        id: capsDebounce
        interval: 120
        onTriggered: capsProbe.running = true
    }

    Component.onCompleted: {
        capsProbe.running = true;
        if (root.idleAfter > 0)
            idleTimer.restart();
        root.startFingerprint();
    }
}
