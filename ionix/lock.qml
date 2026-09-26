// Ionix lock screen — the second entry point in this tree.
//
// Run as its own process by `ionix-lock` (qs -p <this file>), never loaded by
// shell.qml. Being a separate process is the point: the bar hot-reloads, grabs
// screencopy streams and restarts on failure, and none of that may ever take
// the lock with it. Living in the same directory is also the point: `qs.config`
// resolves to the shell's own Config and Theme, so the lock reads the same
// merged theme.json/settings.json/config.json and restyles live with it.
//
// Only services that are safe to run twice are touched from here — Player
// (MPRIS client) and SystemInfo. Nothing in lock/ may reach Notifications:
// there is one notification server per session and it is the bar's.
//
// If this process dies while locked, Hyprland keeps the session locked and
// shows its fallback screen; `misc.allow_session_lock_restore` in hyprland.lua
// lets a fresh `ionix-lock` take over from there.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.lock

ShellRoot {
    id: root

    // `ionix-lock` waits for this before trusting that the screen is covered,
    // and falls back to hyprlock if it never appears.
    readonly property string stateFile: `${Quickshell.env("XDG_RUNTIME_DIR")}/ionix-lock.state`

    Component.onCompleted: {
        // A package upgrade rewriting these files mid-lock must not reload the
        // lock screen under the user. IONIX_LOCK_DEV=1 keeps hot reload for
        // working on it.
        Quickshell.watchFiles = Quickshell.env("IONIX_LOCK_DEV") === "1";
    }

    WlSessionLock {
        id: lock
        locked: true

        onSecureChanged: if (secure)
            state.setText("locked\n")

        LockSurface {}
    }

    FileView {
        id: state
        path: root.stateFile
        printErrors: false
    }

    // Unlocking: the surfaces fade out on LockState.unlocked, then the lock is
    // released, then this process ends. Qt.quit() has no receiver under
    // Quickshell, so it ends itself with a signal like anything else would.
    Connections {
        target: LockState
        function onUnlockedChanged() {
            if (LockState.unlocked)
                release.start();
        }
    }

    Timer {
        id: release
        interval: 300
        onTriggered: {
            lock.locked = false;
            state.setText("unlocked\n");
            exit.start();
        }
    }

    Timer {
        id: exit
        interval: 250
        onTriggered: Quickshell.execDetached(["kill", "-TERM", String(Quickshell.processId)])
    }

    IpcHandler {
        target: "lock"

        function status(): string {
            return `secure=${lock.secure} awake=${LockState.awake} phase=${LockState.phase} fingerprint=${LockState.fingerprintAvailable}`;
        }
        // For a keybind that should blank straight to the screensaver.
        function sleep(): void {
            LockState.buffer = "";
            LockState.clearFailure();
            LockState.awake = false;
        }
        function wake(): void {
            LockState.poke();
        }
    }
}
