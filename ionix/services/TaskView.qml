pragma Singleton

// Whether Task View is up, and the workspace moves it makes. The overlay itself is
// osd/TaskViewOverlay; a module on the bar and an IPC bind can both drive this.

import Quickshell
import Quickshell.Hyprland
import qs.config

Singleton {
    id: root

    property bool active: false

    function toggle() {
        root.active = !root.active && Config.taskView.enabled;
    }

    function close() {
        root.active = false;
    }

    function goTo(id) {
        Compositor.workspace(id);
    }

    // A desktop after the last one on this screen, so it lands at the end of the strip.
    // The number must be free on every screen: focusing one that exists elsewhere jumps
    // there instead of creating it here.
    function newDesktop(desktops) {
        const taken = Hyprland.workspaces.values.map(w => w.id);
        let id = Math.max(0, ...desktops.map(d => d.id)) + 1;
        while (taken.indexOf(id) !== -1)
            id++;
        root.goTo(id);
    }

    // Through this screen's desktops only, for the same reason.
    function step(delta) {
        Compositor.workspaceRelative(delta);
    }
}
