pragma Singleton

// Pinned apps and running windows as one list, one item per application. AppTaskbar
// and the dock both draw this.
//
// A pinned app sits at its pin position whether or not it is open, and apps that are
// running but not pinned follow in the order they were first seen.

import QtQuick
import Quickshell
import qs.config

Singleton {
    id: root

    // The apps to draw on a screen, each { key, entry, title, iconSource, windows }.
    // Windows whose app has no desktop entry are keyed by their app id instead.
    function forScreen(screen) {
        const groups = [];
        const byKey = ({});

        for (const id of StartState.taskbarPins) {
            const entry = Apps.byId(id);
            if (!entry)
                continue;
            byKey[entry.id] = {
                key: entry.id,
                entry: entry,
                title: entry.name,
                iconSource: Apps.iconSource(entry),
                windows: []
            };
            groups.push(byKey[entry.id]);
        }

        for (const toplevel of Windows.forScreen(screen)) {
            const entry = Windows.entryFor(toplevel);
            const key = entry?.id ?? Windows.appId(toplevel);
            if (key === "")
                continue;
            if (!byKey[key]) {
                const iconName = Windows.iconFor(toplevel);
                byKey[key] = {
                    key: key,
                    entry: entry,
                    title: entry?.name ?? key,
                    iconSource: iconName === "" ? "" : Quickshell.iconPath(iconName, true),
                    windows: []
                };
                groups.push(byKey[key]);
            }
            byKey[key].windows.push(toplevel);
        }
        return groups;
    }

    function launch(group) {
        if (group.entry)
            Apps.launch(group.entry);
    }

    // A closed app starts, an open one comes up, and the one already focused moves
    // on to its next window.
    function activate(group) {
        const windows = group.windows;
        if (windows.length === 0) {
            root.launch(group);
            return;
        }
        const at = windows.findIndex(w => w.activated);
        Windows.activate(windows[(at + 1) % windows.length]);
    }

    // `place` names where the pin lives, for the menu's wording: "taskbar", "Dock".
    function menuFor(group, place) {
        const items = [];
        if (group.entry) {
            for (const action of Apps.actionItems(group.entry)) {
                items.push({
                    text: action.text,
                    icon: action.icon,
                    trigger: action.trigger
                });
            }
            if (items.length > 0) {
                items.push({
                    separator: true
                });
            }
            items.push({
                text: group.title,
                glyph: Icons.openExternal,
                trigger: () => root.launch(group)
            }, {
                text: StartState.isTaskbarPinned(group.entry.id) ? `Unpin from ${place}` : `Pin to ${place}`,
                glyph: StartState.isTaskbarPinned(group.entry.id) ? Icons.pinOff : Icons.pin,
                trigger: () => StartState.toggleTaskbarPin(group.entry.id)
            });
        }
        if (group.windows.length > 0) {
            items.push({
                text: group.windows.length === 1 ? "Close window" : `Close all ${group.windows.length} windows`,
                glyph: Icons.close,
                trigger: () => {
                    for (const window of group.windows)
                        Windows.close(window);
                }
            });
        }
        return items;
    }
}
