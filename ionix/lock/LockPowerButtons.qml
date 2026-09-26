// Suspend, restart and shut down from the lock screen — what a login screen
// offers, and what someone at a locked machine that isn't theirs may reasonably
// need. The two that end the session ask for a second click within a few
// seconds; suspend is harmless enough to go at once.
//
// Commands come from Config.power, the same ones the start menu runs.

import QtQuick
import Quickshell
import qs.config

Row {
    id: root

    spacing: Theme.sp1

    // "" | "reboot" | "shutdown"
    property string armed: ""

    function press(action) {
        LockState.poke();
        if (action !== "suspend" && root.armed !== action) {
            root.armed = action;
            disarm.restart();
            return;
        }
        root.armed = "";
        const cmd = Config.power[action];
        if (Array.isArray(cmd) && cmd.length > 0)
            Quickshell.execDetached(cmd);
    }

    Timer {
        id: disarm
        interval: 4000
        onTriggered: root.armed = ""
    }

    LockButton {
        icon: Icons.suspend
        onClicked: root.press("suspend")
    }

    LockButton {
        icon: Icons.reboot
        accent: Theme.orange
        armed: root.armed === "reboot"
        label: armed ? "Restart?" : ""
        onClicked: root.press("reboot")
    }

    LockButton {
        icon: Icons.shutdown
        accent: Theme.red
        armed: root.armed === "shutdown"
        label: armed ? "Shut down?" : ""
        onClicked: root.press("shutdown")
    }
}
