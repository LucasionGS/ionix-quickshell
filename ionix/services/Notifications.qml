pragma Singleton

// swaync bridge.
//
// The shell deliberately does NOT implement a NotificationServer — swaync already
// owns that role in Ionix, and two daemons claiming org.freedesktop.Notifications
// means whichever loses the race silently stops working. This just subscribes to
// swaync's state so the bell can show a count and DND status.
//
// `swaync-client -swb` streams one JSON object per line in waybar's format.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    property int count: 0
    property bool dnd: false
    property bool available: false

    readonly property string client: Config.notifications.client

    Component.onCompleted: probe.running = true

    Process {
        id: probe
        command: ["which", root.client]
        onExited: code => {
            root.available = (code === 0);
            if (root.available)
                subscription.running = true;
        }
    }

    Process {
        id: subscription
        command: [root.client + "-client", "-swb"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (!line || line.trim() === "")
                    return;
                try {
                    const obj = JSON.parse(line);
                    root.count = parseInt(obj.text ?? "0") || 0;
                    root.dnd = (obj.alt ?? "").includes("dnd");
                } catch (e)
                // swaync occasionally emits a partial line on startup; ignore it
                // rather than tearing down the subscription.
                {}
            }
        }
    }

    function toggle() {
        Quickshell.execDetached([root.client + "-client", "-t"]);
    }

    function toggleDnd() {
        Quickshell.execDetached([root.client + "-client", "-d"]);
    }
}
