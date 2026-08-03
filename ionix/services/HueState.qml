pragma Singleton

// Hue bridge credential and pinned lights.
//
// Split out from Hue.qml for the same reason StartState is split from the start
// menu: this is state the shell owns and writes, not configuration a user edits,
// so it lives under XDG_STATE_HOME rather than beside config.json. Config's own
// FileViews are watched and would treat every pin as an external change.
//
// The `username` here is a bearer token for the bridge — anything holding it can
// drive the lights on the LAN. It is not a password and the bridge scopes it to
// itself, but it still has no business being world-readable, so the state
// directory is chmod 700 on creation and writes are atomic.
//
// `data` is always replaced wholesale, never mutated in place: a `property var`
// holding a JS object emits no change signal when a key inside it is assigned,
// so anything bound to `pinned` would silently go stale.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property string path: {
        const override = Config.hue.stateFile;
        if (override && override !== "")
            return override;
        const xdg = Quickshell.env("XDG_STATE_HOME");
        const base = (xdg && xdg !== "") ? xdg : Quickshell.env("HOME") + "/.local/state";
        return `${base}/ionix/quickshell/hue.json`;
    }

    readonly property string dir: root.path.substring(0, root.path.lastIndexOf("/"))

    property var data: ({
            version: 1,
            bridgeIp: "",
            bridgeId: "",
            username: "",
            pinned: []
        })

    readonly property string bridgeIp: root.data.bridgeIp ?? ""
    readonly property string bridgeId: root.data.bridgeId ?? ""
    readonly property string username: root.data.username ?? ""
    readonly property var pinned: root.data.pinned ?? []

    // A bridge we can actually talk to needs both halves.
    readonly property bool paired: root.bridgeIp !== "" && root.username !== ""

    // ── Bridge ──────────────────────────────────────────────────────────────

    function saveBridge(ip, id, username) {
        root.replace({
            bridgeIp: ip ?? "",
            bridgeId: id ?? "",
            username: username ?? ""
        });
    }

    // Drops the credential but keeps the pins, so re-pairing the same bridge
    // lands back on the same Pinned tab. Light ids are stable per bridge.
    function forget() {
        root.replace({
            bridgeIp: "",
            bridgeId: "",
            username: ""
        });
    }

    // ── Pins ────────────────────────────────────────────────────────────────

    function isPinned(id) {
        return root.pinned.indexOf(String(id)) !== -1;
    }

    function togglePin(id) {
        const key = String(id);
        if (!key || key === "")
            return;
        const next = root.pinned.slice();
        const at = next.indexOf(key);
        if (at === -1)
            next.push(key);
        else
            next.splice(at, 1);
        root.replace({
            pinned: next
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
                bridgeIp: typeof parsed.bridgeIp === "string" ? parsed.bridgeIp : "",
                bridgeId: typeof parsed.bridgeId === "string" ? parsed.bridgeId : "",
                username: typeof parsed.username === "string" ? parsed.username : "",
                pinned: Array.isArray(parsed.pinned) ? parsed.pinned.map(String) : []
            };
        } catch (e) {
            console.warn(`[ionix] hue.json: invalid JSON, ignoring — ${e}`);
        }
    }

    // FileView writes the file but not the directory above it. The chmod is what
    // keeps the bridge credential off other accounts on a shared machine; it runs
    // every launch because ~/.local/state/ionix may already exist at 0755 from
    // StartState, which predates this file.
    Process {
        running: true
        command: ["sh", "-c", `mkdir -p "$1" && chmod 700 "$1"`, "sh", root.dir]
    }

    // Deliberately not watched, for the reason spelled out in StartState.qml:
    // reload() is async, so text() read straight after it in onFileChanged returns
    // the *previous* contents and stomps newer in-memory state. This file has
    // exactly one writer, so a watch has nothing to tell us we don't know.
    FileView {
        id: stateFile
        path: root.path
        blockLoading: true
        printErrors: false
        atomicWrites: true

        onLoaded: root.adopt(this.text())
    }
}
