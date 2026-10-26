pragma Singleton

// Project workspaces — the `ionix-project` CLI, as a service.
//
// A project is one workspace saved under a label: its apps and where their
// windows were. The CLI does all the real work (capturing, launching, putting
// windows back) and ships with the Ionix distro, not with this shell, so every
// consumer gates on `available` the same way the theme picker gates on
// Themes.available: elsewhere the whole feature simply isn't there.
//
// The label itself needs no state here. It is the workspace's Hyprland name
// (the CLI renames the workspace), Quickshell keeps HyprlandWorkspace.name
// current from the renameworkspace event, and a workspace that closes takes
// its label with it. So `labelFor` is a pure read and anything bound to it —
// the bar's dots, the switcher's cards — follows a rename live.
//
// Only the list of *saved* projects comes from the CLI. It is re-read when the
// CLI says something changed (`qs ipc call projects refresh`, which it sends
// after every save, rename and delete) and whenever the start menu opens, so a
// file edited by hand is picked up too.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.config

Singleton {
    id: root

    readonly property string bin: Config.projects.bin
    property bool installed: false
    readonly property bool available: root.installed && Config.projects.enabled

    // Rows from `ionix-project list --json`:
    //   { name, slug, file, windows, apps: [class…], savedAt }
    property var list: []

    // The apps of one project, for the start menu's editor: rows from
    // `ionix-project apps <name> --json`, numbered from 1 as the CLI takes them:
    //   { n, class, title, desktop, command, exec, launch, cwd, floating }
    // `command` is what was captured, `exec` a hand-set replacement ("" when
    // none) and `launch` whichever of the two runs.
    property string appsOf: ""
    property var apps: []

    // The focused workspace's label, "" when it has none.
    readonly property string current: root.labelFor(Hyprland.focusedWorkspace)

    // A workspace's label: its name, when that is something other than the
    // number Hyprland names every workspace by default. Special workspaces
    // (scratchpads) are named "special:…" and never count.
    function labelFor(workspace) {
        if (!workspace || workspace.id < 1)
            return "";
        const name = workspace.name ?? "";
        if (name === "" || name === String(workspace.id))
            return "";
        return name;
    }

    function labelForToplevel(toplevel) {
        return root.labelFor(toplevel?.workspace ?? null);
    }

    // The open workspace carrying a project's label, or null. Labels are unique
    // per session — a second copy of a project opens as "Name 2" — so the
    // first match is the only one.
    function workspaceFor(name) {
        return Hyprland.workspaces.values.find(w => w.id > 0 && w.name === name) ?? null;
    }

    function byName(name) {
        const lower = (name ?? "").toLowerCase();
        return root.list.find(p => p.name.toLowerCase() === lower) ?? null;
    }

    // Icons for a project's apps, from the classes it saved; desktop entries
    // first, then the icon theme, so they match the taskbar's.
    function iconsFor(project, max) {
        const out = [];
        const seen = ({});
        for (const cls of project?.apps ?? []) {
            if (cls === "" || seen[cls])
                continue;
            seen[cls] = true;
            const entry = DesktopEntries.byId(cls) ?? DesktopEntries.heuristicLookup(cls);
            const name = entry?.icon || (Quickshell.hasThemeIcon(cls) ? cls : (Quickshell.hasThemeIcon(cls.toLowerCase()) ? cls.toLowerCase() : ""));
            if (name !== "")
                out.push(Quickshell.iconPath(name, true));
            if (out.length >= (max ?? 4))
                break;
        }
        return out;
    }

    // ── Actions ─────────────────────────────────────────────────────────────
    //
    // All detached: a load can take as long as its slowest app takes to show a
    // window, and the CLI reports its own outcome as a notification. Nothing
    // here waits on it; the refresh it sends when done updates the list.

    function run(args) {
        if (!root.available)
            return;
        Quickshell.execDetached([root.bin].concat(args));
    }

    // Jump to the project when it is already open, otherwise open it. This is
    // what a click in the start menu does — loading always starts fresh copies
    // of the apps, so a second load is something to ask for explicitly.
    function focusOrLoad(name) {
        const ws = root.workspaceFor(name);
        if (ws)
            ws.activate();
        else
            root.load(name);
    }

    function load(name) {
        root.run(["load", name]);
    }

    // `workspaceId` omitted saves the focused workspace.
    function save(name, workspaceId) {
        const trimmed = (name ?? "").trim();
        if (trimmed === "")
            return;
        root.run(workspaceId ? ["save", trimmed, "--workspace", String(workspaceId)] : ["save", trimmed]);
    }

    function rename(from, to) {
        const trimmed = (to ?? "").trim();
        if (trimmed === "" || trimmed === from)
            return;
        root.run(["rename", from, trimmed]);
    }

    function remove(name) {
        root.run(["delete", name]);
    }

    // `fields` holds any of exec, cwd and class; an empty exec goes back to
    // the captured command, an empty cwd drops the folder. Values go as
    // `--flag=value` so one starting with a dash is not read as an option.
    function editApp(name, n, fields) {
        const args = ["app", name, String(n)];
        for (const key of ["exec", "cwd", "class"]) {
            if (fields[key] !== undefined)
                args.push(`--${key}=${fields[key]}`);
        }
        root.run(args);
    }

    function removeApp(name, n) {
        root.run(["app", name, String(n), "--remove"]);
    }

    // Start (or stop, with "") following one project's apps. They are re-read
    // with every refresh, which the CLI sends after each change.
    function loadApps(name) {
        root.appsOf = name ?? "";
        // Forget the last read, or reopening the same project would find it
        // unchanged and leave `apps` empty.
        appsLister.last = "";
        if (root.appsOf === "") {
            root.apps = [];
            return;
        }
        root.reloadApps();
    }

    property bool appsStale: false

    function reloadApps() {
        if (!root.installed || root.appsOf === "")
            return;
        if (appsLister.running) {
            root.appsStale = true;
            return;
        }
        appsLister.command = [root.bin, "apps", root.appsOf, "--json"];
        appsLister.running = true;
    }

    function label(name) {
        const trimmed = (name ?? "").trim();
        root.run(trimmed === "" ? ["label", "--clear"] : ["label", trimmed]);
    }

    // Coalesces: a refresh asked for while one is running re-runs once after.
    property bool stale: false

    function refresh() {
        if (!root.installed)
            return;
        if (lister.running) {
            root.stale = true;
            return;
        }
        lister.running = true;
        root.reloadApps();
    }

    // Wrapped in sh for the same reason Themes is: a missing CLI is a clean
    // "not installed" instead of a failed-to-start process on every launch.
    Process {
        running: true
        command: ["sh", "-c", `command -v ${root.bin} >/dev/null 2>&1`]
        onExited: code => {
            root.installed = code === 0;
            if (root.installed)
                root.refresh();
        }
    }

    Process {
        id: lister
        command: [root.bin, "list", "--json"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const rows = JSON.parse(this.text);
                    root.list = Array.isArray(rows) ? rows : [];
                } catch (e) {
                    console.warn(`[ionix] ionix-project list: ${e}`);
                }
            }
        }

        onExited: {
            if (root.stale) {
                root.stale = false;
                Qt.callLater(() => lister.running = true);
            }
        }
    }

    Process {
        id: appsLister

        // The raw text of the last read: a refresh that changed nothing must
        // not hand the editor a new array, which would rebuild its rows and
        // throw away whatever is being typed into one.
        property string last: ""

        stdout: StdioCollector {
            onStreamFinished: {
                // Read for a project the editor has since left.
                if (appsLister.command[2] !== root.appsOf || this.text === appsLister.last)
                    return;
                try {
                    const data = JSON.parse(this.text);
                    appsLister.last = this.text;
                    root.apps = Array.isArray(data?.apps) ? data.apps : [];
                } catch (e) {
                    console.warn(`[ionix] ionix-project apps: ${e}`);
                }
            }
        }

        onExited: code => {
            // The project is gone (deleted, or renamed from somewhere else).
            if (code !== 0 && appsLister.command[2] === root.appsOf) {
                appsLister.last = "";
                root.apps = [];
            }
            if (root.appsStale) {
                root.appsStale = false;
                Qt.callLater(root.reloadApps);
            }
        }
    }
}
