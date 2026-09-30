// Ionix login greeter — the third entry point in this tree, next to shell.qml
// and lock.qml.
//
// Run by `ionix-greeter` inside cage, itself started by greetd as the first
// thing on the machine. It is the lock screen with a username field: same
// LockView, same theme, same background — the ones of whoever logged in last
// (ionix-greeter points HOME at the copy `ionix-greeter-sync` left for them).
//
// cage has no ext-session-lock and no layer-shell, and shows one window at a
// time. With several monitors it extends: that window is sized to the box
// around every output in its layout. So the window is split up here instead —
// one LockView per output, placed at that output's offset in the box and sized
// to it, which mirrors the screen at each monitor's own resolution rather than
// stretching one across all of them.
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
        id: window

        visible: true
        color: Theme.bgDeep
        title: "Ionix greeter"

        // The box cage sizes the window to: every output's logical rect.
        readonly property rect layoutBox: {
            const screens = Quickshell.screens;
            if (screens.length === 0)
                return Qt.rect(0, 0, 0, 0);
            let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
            for (const s of screens) {
                x0 = Math.min(x0, s.x);
                y0 = Math.min(y0, s.y);
                x1 = Math.max(x1, s.x + s.width);
                y1 = Math.max(y1, s.y + s.height);
            }
            return Qt.rect(x0, y0, x1 - x0, y1 - y0);
        }
        // Split only when the window really is that box. Anything else (run as
        // an ordinary window for testing, or cage with `-m last`) gets one view
        // filling the window, as before.
        readonly property bool perScreen: Quickshell.screens.length > 1
            && Math.abs(width - layoutBox.width) <= 1 && Math.abs(height - layoutBox.height) <= 1

        Repeater {
            model: window.perScreen ? Quickshell.screens : [Quickshell.screens.length > 0 ? Quickshell.screens[0] : null]

            LockView {
                required property var modelData
                required property int index

                screen: modelData
                // One item in a window holds focus; keys land in LockState, so
                // every mirror shows the typing anyway.
                input: index === 0
                x: window.perScreen ? modelData.x - window.layoutBox.x : 0
                y: window.perScreen ? modelData.y - window.layoutBox.y : 0
                width: window.perScreen ? modelData.width : window.width
                height: window.perScreen ? modelData.height : window.height
                clip: true
            }
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
