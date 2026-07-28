pragma Singleton

// Hyprland dispatch compatibility.
//
// Hyprland 0.55+ can be configured in Lua, which Ionix does
// (/etc/hypr/hyprland.lua). The two config languages need genuinely different
// arguments, not just different quoting:
//
//   legacy:  "workspace m+1"                       — a dispatcher name and args
//   lua:     hl.dsp.focus({ workspace = "m+1" })   — a dispatcher *object*
//
// Quickshell evaluates the string as `return hl.dispatch(<arg>)` under Lua, so
// the Lua variant is the bare constructor expression. Passing a plain string
// there fails with "expected a dispatcher".
//
// Prefer the typed API (HyprlandWorkspace.activate()) wherever one exists — it
// works under both parsers with no branching at all.

import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    // `lua` is the Lua-parser form; `legacy` the classic hyprlang one.
    function dispatch(legacy, lua) {
        Hyprland.dispatch(Hyprland.usingLua ? lua : legacy);
    }

    function workspace(id) {
        // Typed call: no parser branch, and it targets the workspace object
        // directly rather than re-resolving the ID.
        const ws = Hyprland.workspaces.values.find(w => w.id === id);
        if (ws)
            ws.activate();
        else
            root.dispatch(`workspace ${id}`, `hl.dsp.focus({ workspace = ${id} })`);
    }

    // `m` is monitor-relative: it walks only the workspaces on the current
    // monitor, which is what the bar shows. `e` would cycle every workspace and
    // move focus to another screen.
    function workspaceRelative(delta) {
        const spec = `m${delta > 0 ? "+" : "-"}${Math.abs(delta)}`;
        root.dispatch(`workspace ${spec}`, `hl.dsp.focus({ workspace = "${spec}" })`);
    }

    function toggleSpecial(name) {
        root.dispatch(`togglespecialworkspace ${name}`, `hl.dsp.workspace.toggle_special("${name}")`);
    }
}
