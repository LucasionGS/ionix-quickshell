pragma Singleton

// The start menu's search, as a set of providers over one ranking function.
//
// Every provider returns rows in the same shape, so the menu renders one list and
// the keyboard walks it without caring what a row is:
//
//   kind      app | window | action | theme, used for the section header
//   key       stable identity, for delegate reuse and selection
//   title     the label
//   subtitle  the dim second line, may be ""
//   icon      a resolved icon *path*, or "" to fall back to glyph
//   glyph     icon-font character
//   score     0 excludes the row
//   activate  function run on Enter or click
//
// Scores all come from Apps.matchScore, so a name match means the same thing
// whether it is an application, a window title or a theme. The per-kind weights
// below are the only thing that separates them, and they are deliberately gentle:
// a literal match in a lesser kind should still beat a fuzzy one in a better kind.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config

Singleton {
    id: root

    readonly property real appWeight: 1.0
    readonly property real windowWeight: 0.96
    readonly property real actionWeight: 0.92
    readonly property real themeWeight: 0.88

    readonly property int perKindLimit: 8
    readonly property int totalLimit: 24

    function results(query) {
        const q = query.toLowerCase().trim();
        if (q === "")
            return [];

        const rows = root.apps(q).concat(root.windows(q), root.actions(q), root.themes(q));
        return rows.sort((a, b) => b.score - a.score || a.title.localeCompare(b.title)).slice(0, root.totalLimit);
    }

    function cap(rows) {
        return rows.sort((a, b) => b.score - a.score).slice(0, root.perKindLimit);
    }

    // ── Applications ────────────────────────────────────────────────────────

    function apps(q) {
        const running = root.runningIds();
        const rows = [];

        for (const entry of Apps.list) {
            const base = Apps.score(entry, q);
            if (base <= 0)
                continue;
            const isRunning = running[entry.id] === true;
            rows.push({
                kind: "app",
                key: `app:${entry.id}`,
                title: entry.name,
                subtitle: isRunning ? "Running" : Apps.subtitleFor(entry),
                icon: Apps.iconSource(entry),
                glyph: Icons.apps,
                // Apps you actually use float up, and an app that is already open
                // floats a little further so its window row lands next to it.
                score: base * root.appWeight * StartState.usageBoost(entry.id) * (isRunning ? 1.05 : 1.0),
                activate: () => Apps.launch(entry)
            });
        }
        return root.cap(rows);
    }

    function runningIds() {
        const seen = ({});
        const toplevels = Windows.toplevels;
        for (let i = 0; i < toplevels.length; i++) {
            const entry = Windows.entryFor(toplevels[i]);
            if (entry)
                seen[entry.id] = true;
        }
        return seen;
    }

    // ── Open windows ────────────────────────────────────────────────────────
    //
    // The reason Enter on an open app focuses it instead of starting a second
    // copy: the window row scores off the same query and sits beside the app row.

    function windows(q) {
        const rows = [];
        const toplevels = Windows.toplevels;

        for (let i = 0; i < toplevels.length; i++) {
            const toplevel = toplevels[i];
            const title = toplevel.title ?? "";
            const appId = Windows.appId(toplevel);
            const entry = Windows.entryFor(toplevel);
            const appName = entry?.name ?? appId;

            const score = Math.max(Apps.matchScore(title, q), Apps.matchScore(appName, q) * 0.9, Apps.matchScore(appId, q) * 0.7);
            if (score <= 0)
                continue;

            const workspace = toplevel.workspace?.name ?? "";
            rows.push({
                kind: "window",
                key: `win:${toplevel.address ?? i}`,
                title: title === "" ? appName : title,
                subtitle: workspace === "" ? appName : `${appName}  ·  workspace ${workspace}`,
                icon: Quickshell.iconPath(Windows.iconFor(toplevel), true),
                glyph: Icons.window,
                score: score * root.windowWeight,
                activate: () => Windows.activate(toplevel)
            });
        }
        return root.cap(rows);
    }

    // ── Shell and session actions ───────────────────────────────────────────

    // Built fresh each call so the subtitles reflect current state ("On"/"Off" for
    // Do Not Disturb) rather than whatever they were when the singleton loaded.
    function actionList() {
        const power = Config.power;
        return [
            {
                title: "Do Not Disturb",
                subtitle: Notifications.dnd ? "On — select to turn off" : "Off — select to turn on",
                glyph: Notifications.dnd ? Icons.bellDnd : Icons.bell,
                keywords: ["dnd", "silence", "quiet", "notifications"],
                run: () => Notifications.toggleDnd()
            },
            {
                title: "Notifications",
                subtitle: Notifications.count === 0 ? "Nothing waiting" : `${Notifications.count} waiting`,
                glyph: Icons.bell,
                keywords: ["notification centre", "center", "alerts"],
                run: () => Popouts.open("notifications", null)
            },
            {
                title: "Clear notifications",
                subtitle: "Dismiss everything in the centre",
                glyph: Icons.close,
                keywords: ["clear", "dismiss", "notifications"],
                run: () => Notifications.clearAll()
            },
            {
                title: "Wi-Fi & network",
                subtitle: "Open the network panel",
                glyph: Icons.wifiOff,
                keywords: ["wifi", "network", "internet", "connection"],
                run: () => Popouts.open("network", null)
            },
            {
                title: "Bluetooth",
                subtitle: "Open the bluetooth panel",
                glyph: Icons.bluetoothDevice(""),
                keywords: ["bluetooth", "pair", "devices"],
                run: () => Popouts.open("bluetooth", null)
            },
            {
                title: "Sound",
                subtitle: "Outputs, inputs and per-app volume",
                glyph: Icons.speaker,
                keywords: ["audio", "volume", "sound", "output", "microphone"],
                run: () => Popouts.open("audio", null)
            },
            {
                title: "Calendar",
                subtitle: "Open the calendar",
                glyph: Icons.calendar,
                keywords: ["calendar", "date", "month"],
                run: () => Popouts.open("calendar", null)
            },
            {
                title: "Reload theme",
                subtitle: "Re-read theme.json and config.json",
                glyph: Icons.refresh,
                keywords: ["theme", "reload", "config", "restyle"],
                run: () => Config.reloadAll()
            },
            {
                title: "Reload shell",
                subtitle: "Restart the Quickshell config",
                glyph: Icons.refresh,
                keywords: ["reload", "restart", "shell", "quickshell"],
                run: () => Quickshell.reload(true)
            },
            {
                title: "Lock",
                subtitle: "Lock the session",
                glyph: Icons.lock,
                keywords: ["lock", "screen", "hyprlock"],
                run: () => Quickshell.execDetached(power.lock)
            },
            {
                title: "Log out",
                subtitle: "End the session",
                glyph: Icons.logout,
                keywords: ["logout", "log out", "sign out", "exit"],
                run: () => Quickshell.execDetached(power.logout)
            },
            {
                title: "Suspend",
                subtitle: "Sleep",
                glyph: Icons.suspend,
                keywords: ["suspend", "sleep"],
                run: () => Quickshell.execDetached(power.suspend)
            },
            {
                title: "Restart",
                subtitle: "Reboot the machine",
                glyph: Icons.reboot,
                keywords: ["restart", "reboot"],
                run: () => Quickshell.execDetached(power.reboot)
            },
            {
                title: "Shut down",
                subtitle: "Power off the machine",
                glyph: Icons.shutdown,
                keywords: ["shutdown", "shut down", "power off", "poweroff", "halt"],
                run: () => Quickshell.execDetached(power.shutdown)
            }
        ];
    }

    function actions(q) {
        const rows = [];
        for (const action of root.actionList()) {
            let score = Apps.matchScore(action.title, q);
            for (const keyword of action.keywords)
                score = Math.max(score, Apps.matchScore(keyword, q) * 0.95);
            if (score <= 0)
                continue;
            rows.push({
                kind: "action",
                key: `action:${action.title}`,
                title: action.title,
                subtitle: action.subtitle,
                icon: "",
                glyph: action.glyph,
                score: score * root.actionWeight,
                activate: action.run
            });
        }
        return root.cap(rows);
    }

    // ── Themes ──────────────────────────────────────────────────────────────

    function themes(q) {
        if (!Themes.available)
            return [];

        const rows = [];
        for (const name of Themes.list) {
            if (name === Themes.current)
                continue;
            // "theme" matches every theme, so the whole set is one word away even
            // when you can't remember what any of them are called.
            const score = Math.max(Apps.matchScore(name, q), Apps.matchScore("theme", q) * 0.8);
            if (score <= 0)
                continue;
            rows.push({
                kind: "theme",
                key: `theme:${name}`,
                title: name,
                subtitle: "Switch desktop theme",
                icon: "",
                glyph: Icons.palette,
                score: score * root.themeWeight,
                activate: () => Themes.apply(name)
            });
        }
        return root.cap(rows);
    }

    function sectionLabel(kind) {
        if (kind === "app")
            return "Applications";
        if (kind === "window")
            return "Open windows";
        if (kind === "action")
            return "Actions";
        if (kind === "theme")
            return "Themes";
        return kind;
    }
}
