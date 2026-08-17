pragma Singleton

// Alt+Tab switcher state — the MRU focus history and the session state machine.
// The overlay (osd/SwitcherOverlay.qml) is a dumb view of this; Hyprland binds
// drive it one IPC call per Tab press (see shell.qml's "switcher" handler).
//
// MRU is kept as a list of toplevel *addresses*, not object refs: Hyprland
// destroys a toplevel's QObject when its window closes, and a held ref would
// crash on first property access. Addresses are resolved against the live list
// only when a session opens.
//
// Committing is two-phase on purpose. Hyprland will not hand focus to a window
// while a layer surface holds keyboard focus (see services/ShellFocus.qml), and
// the overlay holds an Exclusive grab while open — so commit() only records the
// target and closes the session, and activation happens from a timer once the
// overlay's focus release has round-tripped through the compositor.
// Qt.callLater is not enough: it fires the same frame, before the surface
// commit reaches Hyprland.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config

Singleton {
    id: root

    // Toplevel addresses, most recently focused first. Always tracked, even
    // with the switcher disabled — history has to exist before it is wanted.
    property var mru: []

    // ── Session state ───────────────────────────────────────────────────────
    // `windows` is frozen at open(): cards must not reshuffle under the user
    // while they cycle. Only window closures mutate it (pruned below).
    property bool active: false
    property var windows: []
    property int selection: 0
    // Screen the session opened on; the overlay on this output is the only one
    // that shows anything, and it cannot jump outputs mid-session.
    property string monitor: ""

    // Commit target by address, resolved late — the window may close during
    // the activation delay.
    property string pendingAddress: ""

    // Where focus came from. Cancelling must hand focus back explicitly:
    // Hyprland leaves *nothing* focused when an Exclusive layer grab releases
    // (verified live), it does not restore the previous window on its own.
    property string restoreAddress: ""

    // Urgency, tracked from the raw event stream ourselves. The toplevel's own
    // `urgent` property missed three of four real urgent>> events in live
    // testing, and a switcher that answers attention requests cannot be built
    // on a flag that usually stays false. Keyed by address; an entry clears
    // when its window takes focus, mirroring the compositor's own rule.
    property var urgentAddresses: ({})

    function isUrgent(toplevel) {
        if (!toplevel)
            return false;
        return root.urgentAddresses[toplevel.address] === true || toplevel.urgent === true;
    }

    function noteActive() {
        const addr = Hyprland.activeToplevel?.address ?? "";
        if (addr === "")
            return;
        const next = root.mru.filter(a => a !== addr);
        next.unshift(addr);
        // Bounded so a long session doesn't accumulate every address ever seen.
        root.mru = next.slice(0, 100);
        // Focus answers the attention request. Replaced wholesale, not deleted
        // in place — a `property var` object emits no change signal otherwise.
        if (root.urgentAddresses[addr]) {
            const cleared = Object.assign({}, root.urgentAddresses);
            delete cleared[addr];
            root.urgentAddresses = cleared;
        }
    }

    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            root.noteActive();
        }
        function onRawEvent(event) {
            if (event.name !== "urgent")
                return;
            const next = Object.assign({}, root.urgentAddresses);
            next[event.data] = true;
            root.urgentAddresses = next;
        }
    }

    // Covers a shell restart mid-session: the focused window is already active,
    // so no change signal is coming to seed the history.
    Component.onCompleted: noteActive()

    // MRU order first, then windows that have never held focus in the same
    // stable workspace-grouped order the taskbar uses, so the tail is
    // predictable rather than IPC discovery order.
    function buildWindows() {
        const only = Config.windowSwitcher.currentWorkspaceOnly;
        const ws = Hyprland.focusedWorkspace;
        const candidates = Hyprland.toplevels.values.filter(t => {
            // Only windows the foreign-toplevel protocol can act on. Helper
            // surfaces (Steam menus, Electron tray shells and the like) appear
            // in Hyprland's IPC list unmapped and without a wlr handle —
            // activate() would no-op on those, so a card for one is a dead
            // button with a blank preview.
            if (!t.wayland || t.lastIpcObject?.mapped === false)
                return false;
            if (!only)
                return true;
            // Startup race: no focused workspace reported yet — better to offer
            // everything than nothing.
            if (!ws)
                return true;
            return t.workspace && t.workspace.id === ws.id;
        });
        const rank = new Map(root.mru.map((a, i) => [a, i]));
        // Urgent windows slot in right behind the active one — second in line,
        // so the first Tab press lands on whatever is demanding attention. The
        // active window is tiered too rather than relying on its MRU rank:
        // focus changes that never went through us (mouse clicks before the
        // shell started) leave the MRU incomplete.
        return candidates.map((t, i) => ({
                    t,
                    i,
                    tier: t.activated ? 0 : (root.isUrgent(t) ? 1 : 2),
                    r: rank.has(t.address) ? rank.get(t.address) : Number.MAX_SAFE_INTEGER,
                    key: Windows.workspaceKey(t)
                })).sort((a, b) => a.tier - b.tier || a.r - b.r || a.key - b.key || a.i - b.i).map(e => e.t);
    }

    // Opens a session without moving the selection — next()/prev() are what the
    // binds call; this alone exists for the IPC `show` debugging entry point.
    function open() {
        if (root.active || !Config.windowSwitcher.enabled)
            return;
        const wins = root.buildWindows();
        if (wins.length === 0)
            return;
        // The bar must not be holding OnDemand focus when the overlay takes its
        // Exclusive grab, or the two shells' surfaces fight over the keyboard.
        Popouts.close();
        root.restoreAddress = Hyprland.activeToplevel?.address ?? "";
        root.windows = wins;
        root.selection = 0;
        // Same startup-race fallback as NotificationToasts: Hyprland may not
        // have reported a focused monitor yet.
        root.monitor = Hyprland.focusedMonitor?.name ?? (Quickshell.screens[0]?.name ?? "");
        root.active = true;
    }

    function cycle(step) {
        // Disabled means the overlay Variants render nothing, but the binds
        // still call us and exit 0 — so their `||` fallback never runs. Keep
        // the keystroke alive by doing what the old binds did.
        if (!Config.windowSwitcher.enabled) {
            if (step >= 0)
                Compositor.dispatch("focusurgentorlast", "hl.dsp.focus({ urgent_or_last = true })");
            else
                Compositor.dispatch("cyclenext prev", "hl.dsp.window.cycle_next({})");
            return;
        }
        if (!root.active) {
            root.open();
            if (!root.active)
                return;
            // First press lands on an urgent window when one exists, else the
            // *previous* window — a quick tap answers the attention request or
            // flips between the two most recent, like urgent_or_last did. The
            // findIndex rather than a hardcoded 1: with nothing focused the
            // urgent window sorts to index 0, which "previous" would skip.
            const urgent = root.windows.findIndex(t => root.isUrgent(t) && !t.activated);
            root.selection = step >= 0 ? (urgent !== -1 ? urgent : Math.min(1, root.windows.length - 1)) : root.windows.length - 1;
            return;
        }
        const n = root.windows.length;
        if (n === 0) {
            root.cancel();
            return;
        }
        root.selection = ((root.selection + step) % n + n) % n;
    }

    function next() {
        cycle(1);
    }

    function prev() {
        cycle(-1);
    }

    function select(index) {
        if (root.active && index >= 0 && index < root.windows.length)
            root.selection = index;
    }

    // Cheap no-op when no session is open: the Alt-release bind spawns this on
    // every Alt release system-wide, not just while switching.
    function commit() {
        if (!root.active)
            return;
        root.pendingAddress = root.windows[root.selection]?.address ?? "";
        root.active = false;
        root.windows = [];
        if (root.pendingAddress !== "")
            commitDelay.restart();
    }

    function cancel() {
        if (!root.active)
            return;
        root.active = false;
        root.windows = [];
        // Cancelling is committing to the window we came from — same delayed
        // activation, same reason (the grab must release first).
        root.pendingAddress = root.restoreAddress;
        root.restoreAddress = "";
        if (root.pendingAddress !== "")
            commitDelay.restart();
    }

    Timer {
        id: commitDelay
        // Long enough for the overlay's keyboard-focus release to round-trip
        // through the compositor; imperceptible next to the exit fade.
        interval: 50
        onTriggered: {
            const addr = root.pendingAddress;
            root.pendingAddress = "";
            const t = Hyprland.toplevels.values.find(t => t.address === addr);
            if (t)
                Windows.activate(t);
        }
    }

    // A window closing mid-session drops out of the frozen list; the selection
    // clamps rather than wrapping so the highlight stays put visually.
    Connections {
        target: Hyprland.toplevels
        enabled: root.active
        function onValuesChanged() {
            const live = root.windows.filter(t => Hyprland.toplevels.values.indexOf(t) !== -1);
            if (live.length === root.windows.length)
                return;
            if (live.length === 0) {
                root.cancel();
                return;
            }
            const kept = root.windows[root.selection];
            const idx = live.indexOf(kept);
            root.windows = live;
            root.selection = idx !== -1 ? idx : Math.min(root.selection, live.length - 1);
        }
    }
}
