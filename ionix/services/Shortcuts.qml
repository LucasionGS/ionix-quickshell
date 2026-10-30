pragma Singleton

// Whether the shortcut list is up, and what it lists. The overlay itself is
// osd/ShortcutsOverlay; an IPC bind, the start menu and a bar module can all drive this.
//
// The list is read from `hyprctl binds` every time it opens, so it is always what
// Hyprland really has, a user's own binds included. A bind's description says
// "Section: what it does", and binds with the same description share a row. One
// without a description still appears, under Other, or the list would lie about
// what is bound.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    property bool active: false

    // [{ title, rows: [{ text, chords: [{ mods, keys, caps, separator }], haystack }] }],
    // in the order Hyprland holds the binds, with Other last. `caps` is `keys` as drawn.
    property var sections: []

    readonly property string otherTitle: "Other"

    // Hyprland's modifier mask, in the order they read best.
    readonly property var modifiers: [
        { mask: 4, label: "Ctrl" },
        { mask: 64, label: "Super" },
        { mask: 8, label: "Alt" },
        { mask: 1, label: "Shift" }
    ]

    // A key that is itself a modifier, as in a bind on tapping Super.
    readonly property var modifierKeys: ({
            "SUPER_L": "Super",
            "SUPER_R": "Super",
            "ALT_L": "Alt",
            "ALT_R": "Alt",
            "CTRL_L": "Ctrl",
            "CTRL_R": "Ctrl",
            "CONTROL_L": "Ctrl",
            "CONTROL_R": "Ctrl",
            "SHIFT_L": "Shift",
            "SHIFT_R": "Shift"
        })

    readonly property var keyLabels: ({
            "left": "←",
            "right": "→",
            "up": "↑",
            "down": "↓",
            "page_up": "PgUp",
            "page_down": "PgDn",
            "bracketleft": "[",
            "bracketright": "]",
            "period": ".",
            "comma": ",",
            "minus": "-",
            "equal": "=",
            "slash": "/",
            "backslash": "\\",
            "semicolon": ";",
            "apostrophe": "'",
            "grave": "`",
            "return": "Enter",
            "escape": "Esc",
            "mouse:272": "Left drag",
            "mouse:273": "Right drag",
            "mouse:274": "Middle drag",
            "mouse_up": "Scroll up",
            "mouse_down": "Scroll down",
            "xf86audioraisevolume": "Volume up",
            "xf86audiolowervolume": "Volume down",
            "xf86audiomute": "Mute",
            "xf86audiomicmute": "Mic mute",
            "xf86audioplay": "Play",
            "xf86audionext": "Next",
            "xf86audioprev": "Previous",
            "xf86audiostop": "Stop",
            "xf86monbrightnessup": "Brightness up",
            "xf86monbrightnessdown": "Brightness down"
        })

    // The numeric keypad, which binds name by keycode so NumLock cannot change them.
    readonly property var keycodeLabels: ({
            "79": "Num 7",
            "80": "Num 8",
            "81": "Num 9",
            "83": "Num 4",
            "84": "Num 5",
            "85": "Num 6",
            "87": "Num 1",
            "88": "Num 2",
            "89": "Num 3",
            "90": "Num 0"
        })

    function toggle() {
        root.active = !root.active && Config.shortcuts.enabled;
        if (root.active)
            reader.running = true;
    }

    function close() {
        root.active = false;
    }

    function keyLabel(bind) {
        if (bind.key === "")
            return root.keycodeLabels[String(bind.keycode)] ?? `Key ${bind.keycode}`;
        const known = root.keyLabels[bind.key.toLowerCase()];
        if (known)
            return known;
        // Example: SPACE, Space, F1, XF86Tools
        const key = bind.key.replace(/^XF86/, "");
        return key.length > 1 && key === key.toUpperCase() && !/\d/.test(key) ? key.charAt(0) + key.slice(1).toLowerCase() : key;
    }

    // Fewer keycaps for what is one idea: all four arrows are one cap, and a long run
    // of numbered keys is a range, 1 … 0. Only numbered keys, because a range of
    // anything else says nothing about what lies between.
    function capsOf(keys) {
        const arrows = ["←", "→", "↑", "↓"];
        if (arrows.every(a => keys.includes(a))) {
            const caps = keys.filter(k => !arrows.includes(k));
            caps.splice(keys.findIndex(k => arrows.includes(k)), 0, arrows.join(" "));
            return { caps, separator: "/" };
        }
        if (keys.length > 4 && keys.every(k => /\d$/.test(k)))
            return { caps: [keys[0], keys[keys.length - 1]], separator: "…" };
        return { caps: keys, separator: "/" };
    }

    // What an undescribed bind does, as far as Hyprland tells.
    // Example: HL.Dispatcher(exec_cmd), function: 0x557434bd8d00
    function fallbackText(bind) {
        const match = /^HL\.Dispatcher\((.+)\)$/.exec(bind.dispatcher);
        return match ? `No description (${match[1]})` : "No description";
    }

    function parse(json) {
        let binds;
        try {
            binds = JSON.parse(json);
        } catch (error) {
            console.warn("[shortcuts] could not read hyprctl binds:", error);
            return [];
        }

        const sections = [];
        const sectionFor = title => {
            let section = sections.find(s => s.title === title);
            if (!section) {
                section = { title, rows: [] };
                sections.push(section);
            }
            return section;
        };

        for (const bind of binds) {
            if (bind.submap !== "")
                continue;
            const held = root.modifierKeys[bind.key];
            // The helpers of a modifier-tap bind (Alt-Tab's release, Super's press).
            if (held && !bind.description)
                continue;

            const colon = bind.description.indexOf(": ");
            const title = colon > 0 ? bind.description.slice(0, colon) : root.otherTitle;
            const text = colon > 0 ? bind.description.slice(colon + 2) : bind.description || root.fallbackText(bind);
            const mods = root.modifiers.filter(m => (bind.modmask & m.mask) && m.label !== held).map(m => m.label);
            const key = held ?? root.keyLabel(bind);

            const section = sectionFor(title);
            // Undescribed binds have nothing in common, however alike their text reads.
            let row = bind.description ? section.rows.find(r => r.text === text) : null;
            if (!row) {
                row = { text, chords: [], haystack: `${title} ${text}` };
                section.rows.push(row);
            }
            const chord = row.chords.find(c => c.mods.join() === mods.join());
            if (chord)
                chord.keys.push(key);
            else
                row.chords.push({ mods, keys: [key] });
            row.haystack += ` ${mods.join(" ")} ${key}`;
        }

        for (const section of sections) {
            for (const row of section.rows) {
                for (const chord of row.chords)
                    Object.assign(chord, root.capsOf(chord.keys));
            }
        }

        const other = sections.findIndex(s => s.title === root.otherTitle);
        if (other >= 0)
            sections.push(sections.splice(other, 1)[0]);
        return sections;
    }

    Process {
        id: reader
        command: ["hyprctl", "binds", "-j"]

        stdout: StdioCollector {
            onStreamFinished: root.sections = root.parse(this.text)
        }
    }
}
