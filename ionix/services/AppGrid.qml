pragma Singleton

// Whether the all-apps overlay is up. The overlay itself is osd/AppGridOverlay; the
// dock, a bar module and an IPC bind can all drive this.

import Quickshell
import qs.config

Singleton {
    id: root

    property bool active: false

    function toggle() {
        root.active = !root.active && Config.appGrid.enabled;
    }

    function close() {
        root.active = false;
    }
}
