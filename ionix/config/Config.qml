pragma Singleton

// Runtime configuration.
//
// Three layers, lowest priority first:
//   1. `defaults` below (shipped, mirrored into defaults.json for documentation)
//   2. ~/.config/quickshell/ionix/theme.json   — written by ionix-settheme
//   3. ~/.config/quickshell/ionix/config.json  — the user's own overrides
//
// Both files are watched, so saving either restyles the running shell — the merged
// `data` property is a binding, and everything downstream reads through it.
//
// Putting user files in ~/.config/quickshell/ionix is safe even though that path
// shadows the system config directory: Quickshell only treats a directory as a
// config if it contains shell.qml, so a directory holding just JSON falls through
// to /etc/xdg/quickshell/ionix and this shell still loads.

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ── Shipped defaults ────────────────────────────────────────────────────
    readonly property var defaults: ({
            bar: {
                height: 46,
                position: "top",
                floating: true,
                radius: 16,
                opacity: 0.82,
                nativeBlur: true,
                margin: {
                    top: 6,
                    left: 8,
                    right: 8
                },
                monitors: ["*"]
            },
            modules: {
                left: ["Launcher", "Workspaces", "Taskbar"],
                center: ["MediaWidget"],
                right: ["Tray", "AudioIndicator", "NetworkIndicator", "BluetoothIndicator", "BatteryIndicator", "Clock", "NotificationBell"]
            },
            theme: {},
            launcher: {
                // U+E000 — the Ionix logo. Only Ionix.ttf provides this codepoint,
                // so Launcher renders it with Theme.fontLogo, not the bar font.
                icon: "",
                command: ["ioexplorer-start", "--top", "--left"],
                middleCommand: ["ioexplorer-spotlight"]
            },
            workspaces: {
                // 0 = show only the workspaces this monitor actually owns. Raise it
                // only if you have per-monitor workspace rules; see Workspaces.qml.
                persistent: 0,
                showEmpty: true
            },
            taskbar: {
                enabled: true,
                maxWidth: 420,
                iconSize: 22,
                currentWorkspaceOnly: true,
                iconOverrides: {}
            },
            media: {
                backend: "auto"          // auto | mpris | toxen-mini | off
                ,
                maxWidth: 180,
                preferred: "toxen"
            },
            clock: {
                format: "HH:mm",
                dateFormat: "ddd d MMM",
                showDate: true
            },
            audio: {
                step: 0.02,
                maxVolume: 1.0
            },
            brightness: {
                step: 0.05,
                device: ""
            },
            network: {
                enabled: true
            },
            bluetooth: {
                enabled: true
            },
            battery: {
                warnAt: 30,
                criticalAt: 15
            },
            notifications: {
                popups: true,
                timeout: 5000,      // ms a toast stays up; critical ones never expire
                maxPopups: 3,
                width: 380,
                monitor: ""         // "" follows the focused monitor
            },
            osd: {
                enabled: true,
                timeout: 1600,
                margin: 120
            },
            power: {
                lock: ["hyprlock", "-c", "/etc/hypr/hyprlock.conf", "--grace", "2"],
                logout: ["uwsm", "stop"],
                suspend: ["systemctl", "suspend"],
                hibernate: ["systemctl", "hibernate"],
                reboot: ["systemctl", "reboot"],
                shutdown: ["systemctl", "poweroff"]
            }
        })

    // ── Layer sources ───────────────────────────────────────────────────────
    property var userData: ({})
    property var themeData: ({})

    readonly property string userDir: {
        const xdg = Quickshell.env("XDG_CONFIG_HOME");
        const base = (xdg && xdg !== "") ? xdg : Quickshell.env("HOME") + "/.config";
        return base + "/quickshell/ionix";
    }

    // ── Merged view ─────────────────────────────────────────────────────────
    readonly property var data: deepMerge(deepMerge(clone(defaults), themeData), userData)

    readonly property var bar: data.bar
    readonly property var modules: data.modules
    readonly property var theme: data.theme
    readonly property var launcher: data.launcher
    readonly property var workspaces: data.workspaces
    readonly property var taskbar: data.taskbar
    readonly property var media: data.media
    readonly property var clock: data.clock
    readonly property var audio: data.audio
    readonly property var brightness: data.brightness
    readonly property var network: data.network
    readonly property var bluetooth: data.bluetooth
    readonly property var battery: data.battery
    readonly property var notifications: data.notifications
    readonly property var osd: data.osd
    readonly property var power: data.power

    // Whether a bar should be created for this screen.
    function wantsScreen(screenName) {
        const list = bar.monitors;
        if (!list || list.length === 0)
            return true;
        return list.some(m => m === "*" || m === screenName);
    }

    // ── Merge helpers ───────────────────────────────────────────────────────

    function isPlainObject(v) {
        return v !== null && typeof v === "object" && !Array.isArray(v);
    }

    function clone(v) {
        return JSON.parse(JSON.stringify(v));
    }

    // Recursive merge. Arrays replace wholesale rather than concatenating — a user
    // listing three modules means three modules, not three appended to the defaults.
    function deepMerge(base, overlay) {
        if (!isPlainObject(overlay))
            return base;
        for (const key in overlay) {
            const ov = overlay[key];
            if (isPlainObject(ov) && isPlainObject(base[key]))
                base[key] = deepMerge(base[key], ov);
            else if (ov !== undefined)
                base[key] = ov;
        }
        return base;
    }

    function parse(view, label) {
        const raw = view.text();
        if (!raw || raw.trim() === "")
            return ({});
        try {
            const parsed = JSON.parse(raw);
            return isPlainObject(parsed) ? parsed : ({});
        } catch (e) {
            console.warn(`[ionix] ${label}: invalid JSON, ignoring — ${e}`);
            return ({});
        }
    }

    function reloadAll() {
        userFile.reload();
        themeFile.reload();
    }

    // ── Watched files ───────────────────────────────────────────────────────
    // printErrors is off because a missing file is the normal case, not an error.

    FileView {
        id: userFile
        path: `${root.userDir}/config.json`
        watchChanges: true
        // Blocking first read: the file is tiny, and loading it async makes the bar
        // build once from defaults and then visibly rebuild from the user config.
        blockLoading: true
        printErrors: false
        onLoaded: root.userData = root.parse(this, "config.json")
        onFileChanged: {
            this.reload();
            root.userData = root.parse(this, "config.json");
        }
        onLoadFailed: root.userData = ({})
    }

    FileView {
        id: themeFile
        path: `${root.userDir}/theme.json`
        watchChanges: true
        // Blocking first read: the file is tiny, and loading it async makes the bar
        // build once from defaults and then visibly rebuild from the user config.
        blockLoading: true
        printErrors: false
        onLoaded: root.themeData = root.parse(this, "theme.json")
        onFileChanged: {
            this.reload();
            root.themeData = root.parse(this, "theme.json");
        }
        onLoadFailed: root.themeData = ({})
    }
}
