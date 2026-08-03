pragma Singleton

// Runtime configuration.
//
// Five layers, lowest priority first:
//   1. `defaults` below (shipped, mirrored into defaults.json for documentation)
//   2. ~/.config/quickshell/ionix/theme.json     — written by ionixtheme
//   3. the active theme's option overlays        — see "Theme options" below
//   4. ~/.config/quickshell/ionix/settings.json  — written by the start menu's
//      settings page; the only layer this shell writes
//   5. ~/.config/quickshell/ionix/config.json    — the user's own overrides
//
// theme.json and config.json are watched, so saving either restyles the running
// shell — the merged `data` property is a binding, and everything downstream reads
// through it. settings.json is not watched; see its FileView below.
//
// config.json sits above settings.json deliberately: a hand-edited file should
// always beat a GUI toggle. The cost is that hand-setting a key the settings page
// also owns makes that switch inert, so the page asks `isOverridden()` and renders
// those rows read-only rather than letting them flip and do nothing.
//
// Layer 3 is how a theme offers choices instead of only stating facts. The theme
// declares them in its own theme.json and they merge just above it, so a theme
// option is a suggestion next to anything either user layer says. Their values
// live in settings.json under `themes.<themename>`, keyed by theme so switching
// away and back doesn't lose them.
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
                right: ["Tray", "AudioIndicator", "NetworkIndicator", "BluetoothIndicator", "HueIndicator", "BatteryIndicator", "Clock", "NotificationBell"]
            },
            theme: {},
            launcher: {
                // U+E000 — the Ionix logo. Only Ionix.ttf provides this codepoint,
                // so Launcher renders it with Theme.fontLogo, not the bar font.
                icon: "",
                command: ["ioexplorer-spotlight"],
                middleCommand: ["ioexplorer-spotlight"]
            },
            start: {
                enabled: true,
                width: 620,
                // Fraction of the screen the menu may grow to before it scrolls.
                maxHeightFraction: 0.72,
                columns: 6,
                iconSize: 40,
                showRunning: true,
                recommend: "frequent",   // frequent | recent
                recommendCount: 8,
                // Seed tiles, used until the user pins something of their own. These
                // are desktop-entry ids without the ".desktop" suffix, the same form
                // a window's app_id resolves to. Ids that match nothing installed are
                // skipped rather than drawn empty, so listing extras is harmless.
                defaultPins: ["io.github.ionix.IoExplorer", "kitty", "firefox", "code", "tabby", "steam"],
                // Where ionixtheme keeps its themes. Only read to pull each theme's
                // colours for the picker swatches.
                stylerDir: "/usr/local/share/ionix/styler",
                stylerBin: "/usr/local/share/ionix/styler/bin/ionixtheme",
                stateFile: ""            // "" → $XDG_STATE_HOME/ionix/quickshell/start.json
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
                // false = every window on this monitor, whichever of its
                // workspaces it lives on. Set true to track the visible one.
                currentWorkspaceOnly: false,
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
            hue: {
                // Off by default: the module is in modules.right above but renders
                // zero-width until this is true, so enabling Hue is a one-line
                // config.json edit rather than a modules-list edit.
                enabled: false,
                // Ask discovery.meethue.com which bridges are on this network during
                // setup. Set false to keep setup entirely on the LAN — the manual IP
                // field still works.
                cloudDiscovery: true,
                // Only ever polled while the popout is open; nothing runs when it's
                // closed, so this is the visible-refresh rate, not a background cost.
                pollInterval: 2000,
                // ms the bridge fades a change over. The API takes 100ms units, so
                // this is rounded to the nearest 100.
                transitionTime: 300,
                // Quick-pick swatches in a light's colour controls.
                presets: ["#ff4d4d", "#ff9f43", "#ffd166", "#2ecc71", "#48dbfb", "#7c3aed", "#c084fc", "#ff7bd5"],
                // The bridge address and credential are not configured here — they
                // are discovered once and written to hue.json, because Config is
                // read-only by design. "" → $XDG_STATE_HOME/ionix/quickshell/hue.json
                stateFile: ""
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
    property var settingsData: ({})

    readonly property string userDir: {
        const xdg = Quickshell.env("XDG_CONFIG_HOME");
        const base = (xdg && xdg !== "") ? xdg : Quickshell.env("HOME") + "/.config";
        return base + "/quickshell/ionix";
    }

    // ── Merged view ─────────────────────────────────────────────────────────
    //
    // The overlays are cloned, not passed straight in. deepMerge assigns an
    // overlay's object by reference when the base has no such key, so a later
    // layer merging into that slot would mutate the earlier layer's own stored
    // object. Harmless while every layer was read-only; not something to leave
    // standing now that settingsData is rewritten at runtime.
    //
    // Every property this reads — including the ones read inside themeOption() —
    // is a tracked dependency, so flipping an option, switching theme or saving
    // any of the files re-runs the whole merge, exactly as a one-line binding did.
    readonly property var data: {
        let merged = deepMerge(clone(root.defaults), clone(root.themeData));
        for (const opt of root.themeOptions) {
            const overlay = root.themeOption(opt.key) === true ? opt.on : opt.off;
            if (isPlainObject(overlay))
                merged = deepMerge(merged, clone(overlay));
        }
        merged = deepMerge(merged, clone(root.settingsData));
        return deepMerge(merged, clone(root.userData));
    }

    readonly property var bar: data.bar
    readonly property var modules: data.modules
    readonly property var theme: data.theme
    readonly property var launcher: data.launcher
    readonly property var start: data.start
    readonly property var workspaces: data.workspaces
    readonly property var taskbar: data.taskbar
    readonly property var media: data.media
    readonly property var clock: data.clock
    readonly property var audio: data.audio
    readonly property var brightness: data.brightness
    readonly property var network: data.network
    readonly property var bluetooth: data.bluetooth
    readonly property var hue: data.hue
    readonly property var battery: data.battery
    readonly property var notifications: data.notifications
    readonly property var osd: data.osd
    readonly property var power: data.power

    // ── Settings (the writable layer) ───────────────────────────────────────
    //
    // Keyed by (section, key) rather than a dotted path: every setting the panel
    // exposes is exactly two levels deep, and a pair needs no parser.

    // The effective value, after the whole merge chain.
    function setting(section, key) {
        return root.data[section]?.[key];
    }

    // True when config.json pins this key. Anything we write to settings.json is
    // then invisible, so the settings page shows the row read-only and says why
    // instead of offering a switch that silently does nothing.
    function isOverridden(section, key) {
        const s = root.userData[section];
        return isPlainObject(s) && s[key] !== undefined;
    }

    // Whether Bar.qml will actually instantiate this module.
    //
    // A module needs two things to appear: its enabled flag, and its name in one
    // of the modules lists. Those lists replace wholesale rather than extend
    // (see deepMerge), so a theme that writes its own layout silently drops any
    // module the shipped defaults gained since it was written — and then the
    // enabled flag has nothing reading it. The settings page checks this so that
    // failure is reported rather than looking like a broken switch.
    function isModuleInBar(name) {
        const m = root.data.modules;
        if (!isPlainObject(m))
            return false;
        for (const side of ["left", "center", "right"])
            if (Array.isArray(m[side]) && m[side].indexOf(name) !== -1)
                return true;
        return false;
    }

    function setSetting(section, key, value) {
        const next = clone(root.settingsData);
        if (!isPlainObject(next[section]))
            next[section] = ({});
        next[section][key] = value;

        // Replaced wholesale, never mutated in place — a `property var` holding a
        // JS object emits no change signal when a key inside it is assigned, so
        // `data` would not re-merge. Assigned before the write so the UI updates
        // now rather than waiting on the file round-trip.
        root.settingsData = next;
        root.lastWritten = JSON.stringify(next, null, 2) + "\n";
        settingsFile.setText(root.lastWritten);
    }

    // The exact text of our own most recent write. setText makes FileView emit
    // loaded again, and adopting that echo would rebuild settingsData from text we
    // just serialised — same values, new object identity, so every binding
    // downstream re-evaluates for nothing.
    property string lastWritten: ""

    // ── Theme options ───────────────────────────────────────────────────────
    //
    // Choices a theme offers rather than decides. Each is declared in the theme's
    // own theme.json under `options`:
    //
    //   { "key": "taskbarLeft", "title": "…", "subtitle": "…", "glyph": "󰖳",
    //     "default": false, "on": { …config patch… }, "off": { …config patch… } }
    //
    // `on`/`off` are ordinary config overlays, merged in by `data` above according
    // to the option's current value; both are optional, and a missing one means
    // "the theme's own baseline already is that state". Only booleans are rendered
    // — the settings page draws switches — but the schema has room for an enum
    // later without moving the values or the storage.
    //
    // Definitions are read from themeData, not the merged `data`: the theme owns
    // what its options *are*, and only their values are the user's to set. (Both
    // keys do flow through the merge into `data.options` / `data.themes`, which is
    // harmless and cheaper than stripping them. Note `data.theme` is the colour
    // palette and `data.themes` is option storage — different things.)
    readonly property var themeOptions: {
        const list = root.themeData.options;
        if (!Array.isArray(list))
            return [];
        return list.filter(o => isPlainObject(o) && typeof o.key === "string" && o.key !== "");
    }

    // The value in force for the current theme: pinned by config.json, else what
    // the settings page last wrote, else what the theme declared.
    function themeOption(key) {
        for (const layer of [root.userData, root.settingsData]) {
            const stored = layer.themes?.[root.currentTheme];
            if (isPlainObject(stored) && stored[key] !== undefined)
                return stored[key];
        }
        const def = root.themeOptions.find(o => o.key === key);
        return def ? def.default === true : undefined;
    }

    // The isOverridden() of theme options, and it has one more way to be true.
    // Besides config.json pinning the value itself, it can pin any key the
    // option's overlays would set — the overlay merges *below* config.json, so the
    // switch would flip and be partly or wholly ignored. Either way the page
    // renders the row read-only instead.
    function isThemeOptionPinned(opt) {
        if (!isPlainObject(opt))
            return false;

        const pinned = root.userData.themes?.[root.currentTheme];
        if (isPlainObject(pinned) && pinned[opt.key] !== undefined)
            return true;

        for (const overlay of [opt.on, opt.off]) {
            if (!isPlainObject(overlay))
                continue;
            for (const section in overlay) {
                const sub = overlay[section];
                if (isPlainObject(sub)) {
                    for (const key in sub)
                        if (isOverridden(section, key))
                            return true;
                } else if (root.userData[section] !== undefined) {
                    // A scalar or array at the top level — config.json naming it
                    // at all is enough to win.
                    return true;
                }
            }
        }
        return false;
    }

    function setThemeOption(key, value) {
        // Nothing to key the entry by. Only reachable with the styler absent, and
        // the settings page hides the section in that case.
        if (root.currentTheme === "")
            return;

        const next = clone(root.settingsData);
        if (!isPlainObject(next.themes))
            next.themes = ({});
        if (!isPlainObject(next.themes[root.currentTheme]))
            next.themes[root.currentTheme] = ({});
        next.themes[root.currentTheme][key] = value;

        // Wholesale replacement and the lastWritten guard, for the same reasons
        // spelled out in setSetting. Cloning all of settingsData is also what
        // keeps other themes' stored options intact.
        root.settingsData = next;
        root.lastWritten = JSON.stringify(next, null, 2) + "\n";
        settingsFile.setText(root.lastWritten);
    }

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
        settingsFile.reload();
        currentThemeFile.reload();
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

    // The name of the theme ionixtheme installed last, which is the key theme
    // options are stored under. Read here rather than through Themes.qml — that
    // is a service and services import config, not the other way round — and
    // Themes.current is an alias of this so the two can't disagree.
    //
    // Empty when the styler isn't installed. Nothing breaks: themes still work
    // (theme.json is just a file), there is simply nowhere to file per-theme
    // values, and the settings page hides the section.
    property string currentTheme: ""

    FileView {
        id: currentThemeFile
        path: `${Quickshell.env("HOME")}/.config/ionix/current-theme`
        watchChanges: true
        blockLoading: true
        printErrors: false

        onLoaded: root.currentTheme = this.text().trim()
        onFileChanged: {
            this.reload();
            root.currentTheme = this.text().trim();
        }
        onLoadFailed: root.currentTheme = ""
    }

    // FileView writes the file but not the directory above it, and a user who has
    // never hand-written a config.json won't have ~/.config/quickshell/ionix yet.
    Process {
        running: true
        command: ["mkdir", "-p", root.userDir]
    }

    // Deliberately not watched, unlike the two above. This shell is its only
    // writer, so a watch has nothing to tell us that setSetting doesn't already
    // know, and StartState.qml records what watching a file you own actually
    // costs: reload() is asynchronous, so the text() read straight after it in
    // onFileChanged returns the *previous* contents and stomps newer state.
    //
    // The cost is that hand-editing settings.json needs a shell reload — or
    // `qs -c ionix ipc call theme reload` — to take effect. For a file the GUI
    // owns, that is the right trade.
    FileView {
        id: settingsFile
        path: `${root.userDir}/settings.json`
        blockLoading: true
        printErrors: false
        atomicWrites: true

        onLoaded: {
            // Our own write echoing back; adopting it would rebuild settingsData
            // from text we just serialised.
            if (this.text() === root.lastWritten)
                return;
            root.settingsData = root.parse(this, "settings.json");
        }
        onLoadFailed: root.settingsData = ({})
    }
}
