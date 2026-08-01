pragma Singleton

// Pinned tiles and launch history for the start menu.
//
// This is the only part of the shell that writes to disk. It lives under
// XDG_STATE_HOME rather than beside config.json because it is state the shell
// maintains, not configuration a user edits — Config's own FileViews would also
// treat a write as an external change and re-merge on every pin.
//
// `data` is always replaced wholesale, never mutated in place: a `property var`
// holding a JS object emits no change signal when a key inside it is assigned,
// so anything bound to `pins` would silently go stale.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property string path: {
        const override = Config.start.stateFile;
        if (override && override !== "")
            return override;
        const xdg = Quickshell.env("XDG_STATE_HOME");
        const base = (xdg && xdg !== "") ? xdg : Quickshell.env("HOME") + "/.local/state";
        return `${base}/ionix/quickshell/start.json`;
    }

    readonly property string dir: root.path.substring(0, root.path.lastIndexOf("/"))

    property var data: ({
            version: 1,
            pins: null,
            usage: ({})
        })

    // Null pins means "never customised" — fall through to the configured seed so
    // a fresh install has a populated grid without ever having written a file.
    readonly property var pins: (root.data.pins === null || root.data.pins === undefined) ? (Config.start.defaultPins ?? []) : root.data.pins

    readonly property var usage: root.data.usage ?? ({})

    // ── Pins ────────────────────────────────────────────────────────────────

    function isPinned(id) {
        return root.pins.indexOf(id) !== -1;
    }

    function togglePin(id) {
        if (!id || id === "")
            return;
        const next = root.pins.slice();
        const at = next.indexOf(id);
        if (at === -1)
            next.push(id);
        else
            next.splice(at, 1);
        root.replace({
            pins: next
        });
    }

    // delta is in grid positions; clamped rather than wrapped, so repeating the
    // action doesn't teleport a tile from one end of the grid to the other.
    function movePin(id, delta) {
        const next = root.pins.slice();
        const at = next.indexOf(id);
        if (at === -1)
            return;
        const to = Math.max(0, Math.min(next.length - 1, at + delta));
        if (to === at)
            return;
        next.splice(at, 1);
        next.splice(to, 0, id);
        root.replace({
            pins: next
        });
    }

    // ── Usage ───────────────────────────────────────────────────────────────

    function recordLaunch(id) {
        if (!id || id === "")
            return;
        const usage = Object.assign({}, root.usage);
        const prev = usage[id];
        usage[id] = {
            count: (prev?.count ?? 0) + 1,
            last: Date.now()
        };
        root.replace({
            usage: usage
        });
    }

    // Multiplier applied to a search hit's score. Logarithmic so a daily driver
    // outranks a near-match without a rarely-used app becoming unreachable, and
    // capped so history can never bury an exact name match.
    function usageBoost(id) {
        const count = root.usage[id]?.count ?? 0;
        return 1 + Math.min(0.6, Math.log(1 + count) / 8);
    }

    function frequent(limit) {
        return root.ranked((a, b) => b.count - a.count || b.last - a.last, limit);
    }

    function recent(limit) {
        return root.ranked((a, b) => b.last - a.last, limit);
    }

    function ranked(compare, limit) {
        const rows = [];
        for (const id in root.usage) {
            const u = root.usage[id];
            rows.push({
                id: id,
                count: u?.count ?? 0,
                last: u?.last ?? 0
            });
        }
        return rows.sort(compare).slice(0, limit).map(r => r.id);
    }

    function clearUsage() {
        root.replace({
            usage: ({})
        });
    }

    // ── Persistence ─────────────────────────────────────────────────────────

    // The exact text of our own most recent write. setText makes FileView emit
    // loaded again, and adopting that echo would rebuild `data` from text we just
    // serialised — same values, new object identity, so every binding downstream
    // re-evaluates for nothing.
    property string lastWritten: ""

    function replace(patch) {
        root.data = Object.assign({}, root.data, patch);
        // Written immediately rather than debounced. Coalescing looked like a
        // saving, but every caller here is a discrete user action — one pin, one
        // nudge, one launch — so there is no burst to coalesce, and the delay lost
        // the edit if the shell reloaded or exited inside it.
        const text = JSON.stringify(root.data, null, 2) + "\n";
        root.lastWritten = text;
        stateFile.setText(text);
    }

    function adopt(raw) {
        if (!raw || raw.trim() === "")
            return;
        if (raw === root.lastWritten)
            return;
        try {
            const parsed = JSON.parse(raw);
            if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed))
                return;
            root.data = {
                version: 1,
                pins: Array.isArray(parsed.pins) ? parsed.pins : null,
                usage: (parsed.usage && typeof parsed.usage === "object") ? parsed.usage : ({})
            };
        } catch (e) {
            console.warn(`[ionix] start.json: invalid JSON, ignoring — ${e}`);
        }
    }

    // FileView writes the file but not the directory above it, and
    // ~/.local/state/ionix won't exist until something creates it.
    Process {
        running: true
        command: ["mkdir", "-p", root.dir]
    }

    // Deliberately not watched, unlike Config's files.
    //
    // This file has exactly one writer — us — so a watch has nothing to tell us
    // that we don't already know, and it actively lied: reload() is asynchronous,
    // so the text() read straight after it in onFileChanged returned the *previous*
    // contents, which then got adopted over newer in-memory state. Two nudges of a
    // tile a second apart were enough to see the second one undone.
    //
    // The cost is that hand-editing start.json needs a shell reload to take effect.
    // For state the shell owns, that is the right trade.
    FileView {
        id: stateFile
        path: root.path
        blockLoading: true
        printErrors: false
        atomicWrites: true

        onLoaded: root.adopt(this.text())
    }
}
