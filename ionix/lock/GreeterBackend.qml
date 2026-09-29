// The greeter's link to greetd, loaded only in greeter mode so that a lock
// screen on a build of Quickshell without the Greetd service is unaffected.
//
// A session is opened for the typed username as soon as there is one, rather
// than at Enter: that is what lets pam_fprintd (when the machine's greetd PAM
// stack has it — `ionix-fingerprint enable`) start listening straight away, the
// same finger-or-password race the lock has. The password prompt that follows is
// answered from LockState.buffer once Enter has been pressed, and not before.
//
// Two properties of Quickshell's Greetd (services/greetd/connection.cpp, 0.3.1)
// shape everything below; both were found by a wrong password logging in:
//
//  - It pairs greetd's replies with requests by its *current* state. Every
//    cancel_session (including the one it sends itself after an auth_error)
//    gets a "success" reply, and if a new session is Authenticating by the time
//    that reply lands, it is taken as "password accepted" and readyToLaunch
//    fires. So a new session is only opened after `settle` has let the cancel's
//    reply drain, and readyToLaunch is only believed if this session actually
//    answered its password prompt or ran a fingerprint scan.
//  - It is not reentrant: it emits authFailure *before* resetting itself, so a
//    handler that calls back into it runs against half-updated state. Nothing
//    here calls Greetd from inside one of its own signals.

import QtQuick
import Quickshell.Services.Greetd
import qs.lock

Item {
    id: root

    // greetd is waiting for the secret.
    property bool promptPending: false
    // Enter was pressed with a password in the buffer.
    property bool submitted: false
    // What this session has actually done; readyToLaunch without either is
    // a reply meant for an earlier request, not a login.
    property bool secretAnswered: false
    property bool fingerprintSeen: false

    readonly property string user: LockState.username.trim()

    // Opens a session once the previous one is fully gone. Everything that
    // wants a fresh session restarts this rather than calling open() directly.
    Timer {
        id: settle
        interval: 600
        onTriggered: {
            if (LockState.unlocked || root.user === "")
                return;
            if (Greetd.state !== GreetdState.Inactive) {
                Greetd.cancelSession();
                settle.restart();
                return;
            }
            root.open();
        }
    }

    function open() {
        root.promptPending = false;
        root.secretAnswered = false;
        root.fingerprintSeen = false;
        LockState.fingerprintMessage = "";
        LockState.fingerprintScanning = false;
        Greetd.createSession(root.user);
    }

    function answer() {
        root.promptPending = false;
        root.submitted = false;
        root.secretAnswered = true;
        Greetd.respond(LockState.buffer);
    }

    // Throws the current session away and opens another once it has drained.
    function restart() {
        root.promptPending = false;
        if (Greetd.state !== GreetdState.Inactive)
            Greetd.cancelSession();
        settle.restart();
    }

    Connections {
        target: LockState

        function onSubmitted() {
            root.submitted = true;
            if (root.promptPending)
                root.answer();
            else if (Greetd.state === GreetdState.Inactive && !settle.running)
                settle.restart();
            // Otherwise a session is on its way; its prompt is answered as soon
            // as it arrives, because `submitted` is set.
        }

        function onUsernameChanged() {
            // Typing a name should not open and cancel a session per letter.
            retarget.restart();
        }
    }

    Timer {
        id: retarget
        interval: 500
        onTriggered: {
            root.submitted = false;
            root.restart();
        }
    }

    Connections {
        target: Greetd

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) {
                // A username prompt would be a PAM stack asking for what
                // createSession already gave it; only a secret is answered.
                if (echoResponse)
                    return;
                root.promptPending = true;
                if (root.submitted)
                    Qt.callLater(() => {
                        if (root.promptPending && root.submitted)
                            root.answer();
                    });
                return;
            }
            // Information: what pam_fprintd says while it listens.
            root.fingerprintSeen = true;
            LockState.fingerprintAvailable = true;
            if (error) {
                LockState.fingerprintScanning = false;
                LockState.fingerprintMessage = message;
            } else {
                LockState.fingerprintScanning = true;
            }
        }

        function onAuthFailure(message) {
            console.info(`[ionix-greeter] greetd: ${message}`);
            LockState.fingerprintScanning = false;
            root.submitted = false;
            root.promptPending = false;
            // greetd's description is PAM's error code ("pam_authenticate:
            // AUTH_ERR"), not something to show anyone. An unknown user and a
            // wrong password look the same on purpose.
            if (LockState.phase === "checking") {
                const n = LockState.failures;
                LockState.fail(n > 0 ? `Wrong username or password (${n + 1})` : "Wrong username or password");
            }
            // Quickshell cancels this session itself right after this signal;
            // the next one waits for that cancel's reply to pass.
            settle.restart();
        }

        function onReadyToLaunch() {
            if (!root.secretAnswered && !root.fingerprintSeen) {
                console.warn("[ionix-greeter] ignoring readyToLaunch for a session that was never answered");
                Qt.callLater(root.restart);
                return;
            }
            LockState.fingerprintScanning = false;
            LockState.succeed();
        }

        function onError(error) {
            console.warn(`[ionix-greeter] greetd: ${error}`);
            LockState.fingerprintScanning = false;
            if (LockState.phase === "checking")
                LockState.fail("Could not reach the login service");
            settle.restart();
        }
    }

    // Starts the session the user asked for. greetd runs it as them, and
    // `exit` ends this greeter (and so cage) once greetd has confirmed it.
    // Returns false when greetd is not ready to launch anything, which the
    // caller must treat as a failed login rather than fade out into nothing.
    function launch(command, environment) {
        if (Greetd.state !== GreetdState.ReadyToLaunch)
            return false;
        Greetd.launch(command, environment, true);
        return true;
    }

    Component.onCompleted: settle.restart()
}
