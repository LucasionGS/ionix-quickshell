pragma Singleton

// Everything the share picker knows that isn't drawing: what xdph offered, what
// is selected, and how the answer gets back to xdph.
//
// xdg-desktop-portal-hyprland runs its picker as a child process and reads one
// line from its stdout. `bin/ionix-share-picker` owns that stdout, so this side
// writes the line to `IONIX_PICKER_OUT` and ends the process; the wrapper prints
// it. The formats (from xdph's ScreencopyShared.cpp):
//
//   [SELECTION]<flags>/screen:<output>
//   [SELECTION]<flags>/window:<handle>          handle as xdph listed it
//   [SELECTION]<flags>/region:<output>@x,y,w,h  logical px from the output's corner
//
// `r` in flags lets the app keep a restore token and reshare without asking.
// Anything else (here: "cancel") is a refusal, and xdph closes the session.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config
import qs.services

Singleton {
    id: root

    // ── Inputs ──────────────────────────────────────────────────────────────

    readonly property string outFile: Quickshell.env("IONIX_PICKER_OUT") ?? ""
    // `--allow-token`, passed when xdph.conf sets `allow_token_by_default`.
    property bool allowToken: Quickshell.env("IONIX_PICKER_ALLOW_TOKEN") === "1"

    // Example (one entry per window, all on one line):
    // 2914[HC>]kitty[HT>]~/development[HE>]94147483012272[HA>]
    // The first field is the low 32 bits of the toplevel handle, which is what a
    // window selection must name; the last is Hyprland's window address in
    // decimal, 0 when xdph has no toplevel mapping.
    readonly property var offered: root.parseWindowList(Quickshell.env("XDPH_WINDOW_SHARING_LIST") ?? "")

    // ── What is on offer ────────────────────────────────────────────────────

    // Left to right, then top to bottom, the way the monitors are arranged.
    readonly property var screens: Quickshell.screens.slice().sort((a, b) => a.x - b.x || a.y - b.y)

    // The workspace showing where the user is, from the wrapper (hyprctl), for
    // the same reason as IONIX_PICKER_MONITOR below.
    readonly property int hostWorkspace: {
        const given = parseInt(Quickshell.env("IONIX_PICKER_WORKSPACE") ?? "");
        return isNaN(given) ? (Hyprland.monitorFor(root.hostScreen)?.activeWorkspace?.id ?? -1) : given;
    }

    // xdph's windows, each joined to the HyprlandToplevel behind it for the
    // icon, workspace and preview. The focused workspace comes first, then by
    // workspace number; windows Hyprland does not know about go last.
    //
    // This list re-sorts while the dialog is open (a window closes or moves),
    // which is why the selection is kept as a handle, not a position.
    readonly property var windows: {
        const tops = Hyprland.toplevels.values;
        const activeWs = root.hostWorkspace;
        const joined = root.offered.map((w, i) => {
            const t = root.toplevelFor(w, tops);
            return {
                handle: w.handle,
                appClass: w.appClass,
                title: w.title,
                toplevel: t,
                order: i,
                key: t === null ? Number.MAX_SAFE_INTEGER : (t.workspace?.id === activeWs ? -1 : Windows.workspaceKey(t))
            };
        });
        return joined.sort((a, b) => a.key - b.key || a.order - b.order);
    }

    readonly property bool hasWindows: root.windows.length > 0

    // ── Selection ───────────────────────────────────────────────────────────

    // "screens", "windows" or "region".
    property string page: "screens"

    // What is selected, by name and handle; the positions follow from them.
    // No window chosen yet means the first card; a chosen one that closed
    // means none, so Share never quietly moves to another window.
    property string screenName: ""
    property string windowHandle: ""
    readonly property int screenIndex: root.screens.findIndex(s => s.name === root.screenName)
    readonly property int windowIndex: root.windowHandle === "" ? (root.windows.length > 0 ? 0 : -1) : root.windows.findIndex(w => w.handle === root.windowHandle)

    function selectScreen(index) {
        const s = root.screens[index];
        if (s)
            root.screenName = s.name;
    }

    function selectWindow(index) {
        const w = root.windows[index];
        if (w)
            root.windowHandle = w.handle;
    }

    // Drawing a region: the dialog hides and every screen takes a drag.
    property bool selectingRegion: false
    // Set once an answer is on its way out, so a second click does nothing.
    property bool finished: false

    readonly property bool canShare: (root.page === "screens" && root.screenIndex >= 0 && root.screenIndex < root.screens.length) || (root.page === "windows" && root.windowIndex >= 0 && root.windowIndex < root.windows.length)

    // The area drawn on the region page: one screen's name and a rect in that
    // screen's logical px. Empty name = nothing drawn yet.
    property string regionScreen: ""
    property rect regionRect: Qt.rect(0, 0, 0, 0)

    function clearRegion() {
        root.regionScreen = "";
        root.regionRect = Qt.rect(0, 0, 0, 0);
    }

    // ── Where the dialog opens ──────────────────────────────────────────────
    //
    // The monitor that was focused when xdph asked, fixed from then on so the
    // dialog never jumps when the pointer wanders. Hyprland's IPC fills
    // focusedMonitor a moment after start, hence the latch and the fallback.

    property string hostName: ""
    readonly property var hostScreen: root.screens.find(s => s.name === root.hostName) ?? null

    // From the wrapper, which asked hyprctl. Quickshell's own focusedMonitor
    // starts out on the first monitor until an event corrects it, so it is only
    // trusted once the timer below has given the wrapper's answer up.
    readonly property string givenMonitor: Quickshell.env("IONIX_PICKER_MONITOR") ?? ""
    property bool settleLate: false

    function settleHost() {
        if (root.hostName !== "")
            return;
        let name = "";
        if (root.screens.some(s => s.name === root.givenMonitor))
            name = root.givenMonitor;
        else if (root.settleLate || root.givenMonitor === "")
            name = Hyprland.focusedMonitor?.name ?? root.screens[0]?.name ?? "";
        if (name === "")
            return;
        console.info(`[ionix-share-picker] opening on ${name} (given: "${root.givenMonitor}")`);
        root.hostName = name;
        // The focused monitor's card is the usual answer.
        root.screenName = name;
    }

    onScreensChanged: {
        // The dialog's monitor went away (unplugged, powered off): nothing is
        // left on screen to answer with, and xdph is waiting. Say no.
        if (root.hostName !== "" && !root.screens.some(s => s.name === root.hostName)) {
            console.warn(`[ionix-share-picker] ${root.hostName} is gone; cancelling`);
            root.cancel();
            return;
        }
        root.settleHost();
    }

    Connections {
        target: Hyprland
        function onFocusedMonitorChanged() {
            root.settleHost();
        }
    }

    Timer {
        running: root.hostName === ""
        interval: 400
        onTriggered: {
            root.settleLate = true;
            root.settleHost();
        }
    }

    Component.onCompleted: root.settleHost()

    readonly property var pages: root.hasWindows ? ["screens", "windows", "region"] : ["screens", "region"]

    function cyclePage(step) {
        const i = root.pages.indexOf(root.page);
        root.page = root.pages[(i + step + root.pages.length) % root.pages.length];
    }

    // ── Answers ─────────────────────────────────────────────────────────────

    function shareSelected() {
        if (root.page === "screens")
            root.shareScreen(root.screens[root.screenIndex]);
        else if (root.page === "windows")
            root.shareWindow(root.windows[root.windowIndex]);
    }

    function shareScreen(screen) {
        if (screen)
            root.answer(`screen:${screen.name}`);
    }

    function shareWindow(entry) {
        if (entry)
            root.answer(`window:${entry.handle}`);
    }

    // x, y, w, h in logical px from the output's top-left corner. The edges are
    // rounded, not position and size apart: at scale 2 the pointer moves in
    // half pixels, and 100.5 + 1819.5 rounded separately ends one px past a
    // 1920 px screen.
    function shareRegion(screen, x, y, w, h) {
        if (!screen)
            return;
        const x0 = Math.max(0, Math.round(x));
        const y0 = Math.max(0, Math.round(y));
        const x1 = Math.min(screen.width, Math.round(x + w));
        const y1 = Math.min(screen.height, Math.round(y + h));
        if (x1 - x0 < 1 || y1 - y0 < 1)
            return;
        root.answer(`region:${screen.name}@${x0},${y0},${x1 - x0},${y1 - y0}`);
    }

    function cancel() {
        root.finish("cancel");
    }

    function answer(selection) {
        root.finish(`[SELECTION]${root.allowToken ? "r" : ""}/${selection}`);
    }

    function finish(line) {
        if (root.finished)
            return;
        root.finished = true;
        console.info(`[ionix-share-picker] ${line}`);
        if (root.outFile !== "")
            out.setText(`${line}\n`);
        else
            console.warn("[ionix-share-picker] IONIX_PICKER_OUT is not set; the answer goes nowhere");
        // Qt.quit() has no receiver under Quickshell (see lock.qml).
        exit.start();
    }

    FileView {
        id: out
        path: root.outFile
        // Written before the process ends, not queued behind it.
        blockWrites: true
        printErrors: false
    }

    Timer {
        id: exit
        interval: 60
        onTriggered: Quickshell.execDetached(["kill", "-TERM", String(Quickshell.processId)])
    }

    // ── Helpers ─────────────────────────────────────────────────────────────

    function parseWindowList(list) {
        const result = [];
        for (const entry of list.split("[HA>]")) {
            const hc = entry.indexOf("[HC>]");
            const ht = entry.indexOf("[HT>]");
            const he = entry.indexOf("[HE>]");
            if (hc < 0 || ht < hc || he < ht)
                continue;
            const handle = entry.slice(0, hc).trim();
            if (!/^\d+$/.test(handle))
                continue;
            result.push({
                handle,
                appClass: entry.slice(hc + 5, ht),
                title: entry.slice(ht + 5, he),
                address: root.hexAddress(entry.slice(he + 5).trim())
            });
        }
        return result;
    }

    // xdph prints the address in decimal; HyprlandToplevel.address is hex
    // without the 0x. Real addresses fit a double exactly (they are under 2^48).
    function hexAddress(decimal) {
        if (!/^\d+$/.test(decimal) || decimal === "0")
            return "";
        return Number(decimal).toString(16);
    }

    function toplevelFor(w, tops) {
        if (w.address !== "") {
            const byAddress = tops.find(t => t.address === w.address);
            if (byAddress)
                return byAddress;
        }
        // No mapping from xdph: the same class and title is the best guess.
        return tops.find(t => Windows.appId(t) === w.appClass && (t.title ?? "") === w.title) ?? null;
    }
}
