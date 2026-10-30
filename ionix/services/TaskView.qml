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

    function step(delta) {
        const current = Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1;
        const next = Math.max(1, current + delta);
        if (next !== current)
            root.goTo(next);
    }
}
