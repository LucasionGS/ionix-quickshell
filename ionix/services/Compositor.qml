pragma Singleton

// Hyprland dispatch compatibility.
//
// Hyprland 0.55+ can be configured in Lua (which Ionix does — /etc/hypr/hyprland.lua).
// In that mode the IPC request is evaluated as Lua, so `dispatch workspace 3`
// arrives as `hl.dispatch(workspace 3)` and fails to parse. Quoting the argument
// turns it into a Lua string literal, which works.
//
// Everything that can go through a typed API (workspace.activate()) should — this
// is only for dispatches with no object to call.

import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    function dispatch(command) {
        Hyprland.dispatch(Hyprland.usingLua ? JSON.stringify(command) : command);
    }

    function workspace(id) {
        // Prefer the typed call; it handles both config languages itself.
        const ws = Hyprland.workspaces.values.find(w => w.id === id);
        if (ws)
            ws.activate();
        else
            root.dispatch(`workspace ${id}`);
    }

    function workspaceRelative(delta) {
        root.dispatch(`workspace ${delta > 0 ? "e+" : "e-"}${Math.abs(delta)}`);
    }

    function toggleSpecial(name) {
        root.dispatch(`togglespecialworkspace ${name}`);
    }
}
