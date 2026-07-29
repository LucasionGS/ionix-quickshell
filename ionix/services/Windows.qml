pragma Singleton

// Window list for the taskbar.
//
// Hyprland's IPC toplevels carry the workspace/monitor association we need for
// per-monitor filtering, and each one links to its wlr-foreign-toplevel handle
// via `.wayland` — that handle is what we actually act on, so focus and close go
// through the protocol instead of a `hyprctl dispatch` round trip.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config

Singleton {
    id: root

    // Empty (rather than broken) under a non-Hyprland compositor: the singleton
    // simply never populates, so the taskbar renders as zero items.
    readonly property var toplevels: Hyprland.toplevels.values

    // Windows to show on a given screen: everything on this monitor, across all
    // of its workspaces. Set taskbar.currentWorkspaceOnly to narrow it to the
    // workspace currently visible there.
    //
    // Grouped by workspace, because the IPC list is in discovery order and would
    // otherwise interleave workspaces arbitrarily — and that order churns as
    // windows open and close, moving buttons out from under the pointer.
    function forScreen(screen) {
        if (!screen)
            return [];
        const matching = root.toplevels.filter(t => {
            if (!t.monitor || t.monitor.name !== screen.name)
                return false;
            if (!Config.taskbar.currentWorkspaceOnly)
                return true;
            const active = t.monitor.activeWorkspace;
            return active && t.workspace && t.workspace.id === active.id;
        });
        // Index tiebreak keeps creation order within a workspace, so sorting is
        // stable regardless of the engine's sort implementation.
        return matching.map((t, i) => ({
                    t,
                    i,
                    key: root.workspaceKey(t)
                })).sort((a, b) => a.key - b.key || a.i - b.i).map(e => e.t);
    }

    // Sort key for a window's workspace. Special workspaces (scratchpads) carry
    // negative ids in Hyprland; they belong after the numbered ones, not before.
    function workspaceKey(toplevel) {
        const id = toplevel?.workspace?.id;
        if (id === undefined || id === null)
            return Number.MAX_SAFE_INTEGER;
        return id < 0 ? Number.MAX_SAFE_INTEGER - 1 : id;
    }

    function appId(toplevel) {
        return toplevel?.wayland?.appId ?? toplevel?.lastIpcObject?.class ?? "";
    }

    // The installed .desktop file behind a window, or null. byId wants an exact
    // match on the entry's id; heuristicLookup is what catches the apps whose
    // app_id and desktop file disagree in case or suffix.
    function entryFor(toplevel) {
        const id = appId(toplevel);
        if (id === "")
            return null;
        return DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id);
    }

    // Resolve a window to an icon: user override, then the desktop entry, then a
    // heuristic lookup, then a generic fallback so the taskbar never has holes.
    function iconFor(toplevel) {
        const id = appId(toplevel);
        if (id === "")
            return "application-x-executable";

        const overrides = Config.taskbar.iconOverrides;
        if (overrides && overrides[id])
            return overrides[id];

        const entry = root.entryFor(toplevel);
        if (entry?.icon)
            return entry.icon;

        if (Quickshell.hasThemeIcon(id))
            return id;
        const lower = id.toLowerCase();
        if (Quickshell.hasThemeIcon(lower))
            return lower;

        // Nothing in the theme matches. Return empty rather than a name we know
        // will miss, so the taskbar draws its own placeholder instead of logging
        // a failed icon lookup for every window of this app.
        return "";
    }

    function activate(toplevel) {
        if (toplevel?.wayland)
            toplevel.wayland.activate();
    }

    function close(toplevel) {
        if (toplevel?.wayland)
            toplevel.wayland.close();
    }

    // The app's own actions, as declared by the Actions= key of its .desktop file
    // — Chrome's "New Window"/"New Incognito Window", Steam's "Store"/"Library",
    // and so on. Plenty of apps declare none, which is a legitimate empty result
    // rather than a lookup failure.
    //
    // `actions` arrives as a QList of QObjects: array-like, but not guaranteed to
    // carry the Array prototype, so copy it before using Array methods on it.
    function actionsFor(toplevel) {
        const out = [];
        const actions = root.entryFor(toplevel)?.actions;
        if (!actions)
            return out;
        for (let i = 0; i < actions.length; i++)
            out.push(actions[i]);
        return out;
    }

    // Context-menu model for a window, in the shape ContextMenu expects.
    //
    // Each action runs execute(), which launches it detached through the entry's
    // own Exec line — these start new instances, they don't manipulate the window
    // that was clicked. Close is the one entry not sourced from the desktop file;
    // it acts on this specific window via the wlr handle.
    function menuFor(toplevel) {
        const items = root.actionsFor(toplevel).map(action => ({
                    text: action.name,
                    icon: action.icon ?? "",
                    trigger: () => action.execute()
                }));

        if (items.length > 0)
            items.push({
                separator: true
            });

        items.push({
            text: "Close",
            glyph: Icons.close,
            danger: true,
            trigger: () => root.close(toplevel)
        });

        return items;
    }
}
