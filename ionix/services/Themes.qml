pragma Singleton

// The ionixtheme CLI, as a service.
//
// Every consumer must gate on `available`: ionixtheme ships with the Ionix distro,
// not with this shell, so on any other system the list stays empty and the theme
// UI disappears rather than erroring.
//
// Applying a theme needs nothing from us afterwards — ionixtheme's own installer
// ends with `qs -c ionix ipc call theme reload`, so the running shell restyles
// itself the moment the symlink lands.

import QtQml
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    property var list: []
    readonly property bool available: root.list.length > 0

    // Read from the file ionixtheme writes rather than shelling out again: this
    // way the menu also follows a theme switched from a terminal. Config owns the
    // FileView because it needs the name too — theme options are stored per theme
    // — and it cannot import this file without a cycle.
    readonly property string current: Config.currentTheme

    // The ionixtheme executable
    readonly property string bin: Config.start.stylerBin

    // name → { accent, accentBright, bg }, for the picker's preview dots.
    property var swatches: ({})

    function apply(name) {
        if (!name || name === "" || name === root.current)
            return;
        Quickshell.execDetached([root.bin, name]);
    }

    function swatch(name) {
        return root.swatches[name] ?? null;
    }

    function absorbSwatch(name, raw) {
        if (!raw || raw.trim() === "")
            return;
        try {
            const theme = JSON.parse(raw).theme;
            if (!theme)
                return;
            // Replaced wholesale — assigning into a `property var` object emits no
            // change signal, so the swatches would never repaint.
            const next = Object.assign({}, root.swatches);
            next[name] = {
                accent: theme.accent ?? "",
                accentBright: theme.accentBright ?? theme.accent ?? "",
                bg: theme.bgWindow ?? theme.bgDeep ?? ""
            };
            root.swatches = next;
        } catch (e) {
            console.warn(`[ionix] theme ${name}: invalid theme.json — ${e}`);
        }
    }

    // Wrapped in sh rather than run directly so a missing ionixtheme is a clean
    // empty result instead of a failed-to-start process on every shell launch.
    Process {
        running: true
        command: ["sh", "-c", `command -v ${root.bin} >/dev/null 2>&1 && ${root.bin} --list`]

        stdout: StdioCollector {
            onStreamFinished: root.list = this.text.split("\n").map(l => l.trim()).filter(l => l !== "")
        }
    }

    // One FileView per theme, over the same theme.json the styler symlinks into
    // place. Instantiator rather than Repeater because a singleton has no visual
    // tree to parent a Repeater to.
    Instantiator {
        model: root.list

        delegate: FileView {
            required property string modelData

            path: `${Config.start.stylerDir}/themes/${modelData}/quickshell/theme.json`
            blockLoading: true
            printErrors: false

            onLoaded: root.absorbSwatch(this.modelData, this.text())
        }
    }
}
