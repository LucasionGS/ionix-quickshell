// Ionix login greeter — the third entry point in this tree, next to shell.qml
// and lock.qml.
//
// Run by `ionix-greeter` inside cage, itself started by greetd as the first
// thing on the machine. It is the lock screen with a username field: same
// LockView, same theme, same background — the ones of whoever logged in last
// (ionix-greeter points HOME at the copy `ionix-greeter-sync` left for them).
//
// cage has no ext-session-lock and shows one window at a time, so this is one
// ordinary fullscreened window on the first output, not a lock surface per
// monitor.
//
// Environment (set by bin/ionix-greeter):
//   IONIX_GREETER=1        turns LockState into the greeter
//   IONIX_GREETER_DRY=1    no greetd: PAM checks the password, nothing launches
//   IONIX_GREETER_DIR      where last-user lives (default /var/lib/ionix-greeter)

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.lock

ShellRoot {
    id: root

    readonly property string stateDir: {
        const d = Quickshell.env("IONIX_GREETER_DIR");
        return (d && d !== "") ? d : "/var/lib/ionix-greeter";
    }

    Component.onCompleted: {
        // Nothing here should reload under someone typing their password.
        Quickshell.watchFiles = false;
    }

    FloatingWindow {
        visible: true
        color: Theme.bgDeep
        title: "Ionix greeter"

        LockView {
            anchors.fill: parent
            screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
        }
    }

    // The real thing. Not loaded for a dry run, which is also what keeps this
    // file loadable on a Quickshell without the Greetd service.
    Loader {
        id: backend
        active: !LockState.greeterDry
        source: "lock/GreeterBackend.qml"
    }

    // ── Who logged in last ──────────────────────────────────────────────────

    FileView {
        id: lastUser
        path: `${root.stateDir}/last-user`
        blockLoading: true
        printErrors: false
        onLoaded: {
            const name = this.text().trim();
            LockState.username = name;
            // Nobody known: the username is the first thing to fill in.
            LockState.usernameEditing = name === "";
        }
        onLoadFailed: LockState.usernameEditing = true
    }

    // ── Success ─────────────────────────────────────────────────────────────
    //
    // LockView fades out on LockState.unlocked; then the session starts.

    Connections {
        target: LockState
        function onUnlockedChanged() {
            if (!LockState.unlocked)
                return;
            // Recorded before launching: launch ends this process.
            lastUser.setText(LockState.username.trim() + "\n");
            start.start();
        }
    }

    Timer {
        id: start
        interval: 350
        onTriggered: {
            const cmd = Config.greeter?.command ?? ["uwsm", "start", "hyprland-uwsm.desktop"];
            if (LockState.greeterDry) {
                console.info(`[ionix-greeter] dry run: would start ${JSON.stringify(cmd)} as ${LockState.username.trim()}`);
                Quickshell.execDetached(["kill", "-TERM", String(Quickshell.processId)]);
            } else if (!backend.item || !backend.item.launch(cmd, [])) {
                // greetd was not actually ready. Never fade out into nothing:
                // put the card back up with the reason and let them try again.
                console.warn("[ionix-greeter] greetd is not ready to launch; back to the login card");
                LockState.unlocked = false;
                LockState.phase = "failed";
                LockState.message = "Could not start the session — try again";
                LockState.failed();
                backend.item?.restart();
            }
        }
    }
}
