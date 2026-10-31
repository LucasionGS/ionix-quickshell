pragma Singleton

// Keeps the idle lock in step with `idle.enabled` and `idle.minutes`: bin/ionix-idle
// writes hypridle's config and enables or disables its unit. Done on every shell
// start as well as on a change, so the setting is the one thing that decides, and a
// new account or an upgraded one gets the default without a migration.
//
// hypridle rather than an IdleMonitor in the shell: it has to go on locking when the
// shell has crashed, and it also honours inhibitors sent over D-Bus. Only shell.qml
// may touch this, never the lock or the greeter.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property bool enabled: Config.idle.enabled === true
    readonly property int minutes: Config.idle.minutes

    // Whether hypridle is installed. The settings page hides its rows otherwise,
    // since the AUR package also runs off Ionix.
    property bool available: false
    // ~/.config/hypr/hypridle.conf is in charge of the timeout.
    property bool ownConfig: false

    onEnabledChanged: apply.restart()
    onMinutesChanged: apply.restart()

    // One command for a burst of clicks, or two would race over the unit.
    Timer {
        id: apply
        interval: 400
        onTriggered: {
            if (root.available)
                Quickshell.execDetached(root.enabled ? ["ionix-idle", "on", String(root.minutes)] : ["ionix-idle", "off"]);
        }
    }

    Process {
        running: true
        // Example:
        // on
        // generated
        command: ["sh", "-c", "command -v ionix-idle >/dev/null && ionix-idle status"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n");
                root.ownConfig = lines[1] === "own";
                root.available = lines.length === 2;
                apply.restart();
            }
        }
    }
}
