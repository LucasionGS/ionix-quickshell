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
// Prefer the typed API wherever one exists — it works under both parsers with
// no branching at all. HyprlandWorkspace.activate() is the exception, see
// workspace() below.

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
        // activate() focuses the workspace's *name*. Since Hyprland 0.57 a label
        // is only a display name, so on a labeled workspace that opened a new
        // empty workspace called the same. Only one with no number needs it.
        const ws = id > 0 ? null : Hyprland.workspaces.values.find(w => w.id === id);
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

    // Renaming a workspace to its own id is how a label is cleared.
    function renameWorkspace(id, name) {
        root.dispatch(`renameworkspace ${id} ${name}`, `hl.dsp.workspace.rename({ workspace = ${id}, name = ${JSON.stringify(name)} })`);
    }

    // Parks the focused window out of sight, and brings it back from there. The Lua
    // config defines the toggle; hyprctl eval is how to reach it.
    function minimizeActive() {
        if (Hyprland.usingLua)
            Quickshell.execDetached(["hyprctl", "eval", "ionix_bars_toggle_minimize()"]);
        else
            root.dispatch("movetoworkspacesilent special", "");
    }

    // A window parked by minimizeActive, back onto the workspace in view on its monitor,
    // and focused. One Lua chunk so the two steps cannot swap: focus reaching the window
    // while it is still parked opens the special workspace and leaves it open.
    function restoreWindow(toplevel) {
        const id = toplevel.monitor?.activeWorkspace?.id ?? Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1;
        const address = `address:0x${toplevel.address}`;
        if (Hyprland.usingLua) {
            Quickshell.execDetached(["hyprctl", "eval", `hl.dispatch(hl.dsp.window.move({ window = "${address}", workspace = ${id}, follow = false })); hl.dispatch(hl.dsp.focus({ window = "${address}" }))`]);
        }
        else {
            Hyprland.dispatch(`movetoworkspacesilent ${id},${address}`);
            Hyprland.dispatch(`focuswindow ${address}`);
        }
    }

    function toggleSpecial(name) {
        root.dispatch(`togglespecialworkspace ${name}`, `hl.dsp.workspace.toggle_special("${name}")`);
    }
}
