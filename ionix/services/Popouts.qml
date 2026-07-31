pragma Singleton

// Tracks which popout is open.
//
// A single string rather than a bool per module, so opening one implicitly closes
// the others and there's no way to get two panels on screen at once. It also gives
// the IPC handler something trivial to drive.

import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    // "" when nothing is open. Otherwise: start, calendar, audio, network,
    // bluetooth, media, power, notifications.
    property string current: ""
    // Which screen the open popout belongs to, so a click on monitor B doesn't
    // leave monitor A's panel showing. Null means "wherever focus is" — that's
    // what IPC calls produce, since a command line has no screen to point at.
    property var screen: null

    function isOpen(name, forScreen) {
        if (root.current !== name)
            return false;
        if (!forScreen)
            return true;
        if (root.screen)
            return root.screen === forScreen;
        // Opened without a screen: show it on the focused monitor only, so an IPC
        // call doesn't put the same panel on every display at once.
        return Hyprland.focusedMonitor?.name === forScreen.name;
    }

    function open(name, forScreen) {
        root.screen = forScreen ?? null;
        root.current = name;
    }

    function close() {
        root.current = "";
        root.screen = null;
    }

    function toggle(name, forScreen) {
        if (root.isOpen(name, forScreen))
            root.close();
        else
            root.open(name, forScreen);
    }
}
