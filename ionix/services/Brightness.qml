pragma Singleton

// Backlight control via brightnessctl.
//
// There is no DBus/UPower path for backlight, and sysfs inotify doesn't fire
// reliably for brightness writes, so this owns the value: we write through
// brightnessctl and keep our own copy rather than polling for it. `available` is
// false on desktops, which hides the OSD and any brightness UI.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    property real value: 0          // 0..1
    property bool available: false
    property int maxRaw: 0
    readonly property real step: Config.brightness.step

    readonly property var _deviceArgs: Config.brightness.device !== "" ? ["-d", Config.brightness.device] : []

    Component.onCompleted: probe.running = true

    // `-m` gives machine-readable: name,class,current,percent,max
    Process {
        id: probe
        command: ["brightnessctl", "-m"].concat(root._deviceArgs)
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.trim().split("\n")[0];
                if (!line)
                    return;
                const parts = line.split(",");
                if (parts.length < 5)
                    return;
                const current = parseInt(parts[2]);
                const max = parseInt(parts[4]);
                if (!isFinite(max) || max <= 0)
                    return;
                root.maxRaw = max;
                root.value = current / max;
                root.available = true;
            }
        }
        // brightnessctl missing, or no backlight device — stay unavailable.
        onExited: (code, status) => {
            if (code !== 0)
                root.available = false;
        }
    }

    Process {
        id: setter
    }

    function set(v) {
        if (!root.available)
            return;
        // Never let a keybind take the screen fully dark — 1% is the floor.
        const clamped = Math.max(0.01, Math.min(1, v));
        root.value = clamped;
        setter.running = false;
        setter.command = ["brightnessctl"].concat(root._deviceArgs).concat(["-n", "set", `${Math.round(clamped * 100)}%`]);
        setter.running = true;
    }

    function stepBrightness(direction) {
        set(root.value + direction * root.step);
    }
}
