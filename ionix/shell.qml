// Ionix Quickshell — entry point.
//
// System defaults live in /etc/xdg/quickshell/ionix. User overrides go in
// ~/.config/quickshell/ionix/config.json — see the README for why that path is
// safe despite sharing this directory's name.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config
import qs.modules
import qs.osd
import qs.services

ShellRoot {
    id: root

    // Hyprland 0.57's focusedmon event gives the workspace's address, which
    // Quickshell 0.3.2 looks up as a name: on a labeled workspace it finds none
    // and clears the monitor's active workspace. Monitors re-read by address.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "focusedmon")
                Hyprland.refreshMonitors();
        }
    }

    // One bar per screen the config allows.
    Variants {
        model: Quickshell.screens.filter(s => Config.wantsScreen(s.name))

        delegate: Bar {}
    }

    // One OSD per screen — a PanelWindow lives on a single output, so sharing one
    // would pin the display to whichever monitor happened to be first.
    Variants {
        model: Config.osd.enabled ? Quickshell.screens : []

        delegate: OsdWindow {}
    }

    // Same reasoning for toasts, except only the target screen ever shows them —
    // see NotificationToasts.
    Variants {
        model: Quickshell.screens

        delegate: NotificationToasts {}
    }

    // Alt+Tab switcher — one fullscreen overlay per screen, but only the screen
    // the session opened on ever shows it (see SwitcherOverlay).
    Variants {
        model: Config.windowSwitcher.enabled ? Quickshell.screens : []

        delegate: SwitcherOverlay {}
    }

    // Task View. Stays unmapped until something opens it (TaskViewButton, or
    // `qs ipc call taskview toggle`), so one per screen costs nothing otherwise.
    Variants {
        model: Quickshell.screens

        delegate: TaskViewOverlay {}
    }

    // The dock, where a theme or the user asks for one.
    Variants {
        model: Config.dock.enabled ? Quickshell.screens.filter(s => Config.wantsScreen(s.name)) : []

        delegate: DockWindow {}
    }

    // The all-apps overlay. Unmapped until something opens it.
    Variants {
        model: Config.appGrid.enabled ? Quickshell.screens : []

        delegate: AppGridOverlay {}
    }

    // A singleton only starts when something names it, and the idle lock has to
    // follow its setting from the shell's first moment.
    readonly property bool idleLockFollowsSetting: Idle.enabled

    // The shortcut list. Unmapped until something opens it.
    Variants {
        model: Config.shortcuts.enabled ? Quickshell.screens : []

        delegate: ShortcutsOverlay {}
    }

    // Optional user extension, loaded as-is when the file exists.
    Loader {
        source: userProbe.loaded ? `file://${Config.userDir}/user.qml` : ""
        onStatusChanged: {
            if (status === Loader.Error)
                console.warn("[ionix] user.qml failed to load — see the errors above");
        }
    }

    // Cheapest existence check available without spawning a process.
    FileView {
        id: userProbe
        path: `${Config.userDir}/user.qml`
        printErrors: false
        blockLoading: true
    }

    // ── IPC ─────────────────────────────────────────────────────────────────
    // Bind the media keys to these instead of wpctl/brightnessctl and the OSD gets
    // exact values with no polling. Keep a `|| <original command>` fallback in the
    // bind so the keys still work when the shell isn't running.

    IpcHandler {
        target: "audio"

        function increase(): void {
            Audio.stepVolume(1);
        }
        function decrease(): void {
            Audio.stepVolume(-1);
        }
        function mute(): void {
            Audio.toggleMute();
        }
        function micMute(): void {
            Audio.toggleSourceMute();
        }
        function set(percent: int): void {
            Audio.setVolume(percent / 100);
        }
    }

    IpcHandler {
        target: "brightness"

        function increase(): void {
            Brightness.stepBrightness(1);
            Osd.showBrightness(Brightness.value);
        }
        function decrease(): void {
            Brightness.stepBrightness(-1);
            Osd.showBrightness(Brightness.value);
        }
        function set(percent: int): void {
            Brightness.set(percent / 100);
            Osd.showBrightness(Brightness.value);
        }
    }

    // Hue over IPC so lights can go on a keybind without opening the panel. Each
    // of these is a one-shot write followed by the service's own confirm fetch —
    // none of them start polling, which only ever runs while the popout is open.
    IpcHandler {
        target: "hue"

        function toggle(): void {
            Hue.setAll({
                on: !Hue.anyOn
            });
        }
        function on(): void {
            Hue.setAll({
                on: true
            });
        }
        function off(): void {
            Hue.setAll({
                on: false
            });
        }
        function set(percent: int): void {
            Hue.setGroupBrightness(percent / 100);
        }
        function light(id: string, on: bool): void {
            Hue.setLight(id, {
                on: on
            });
        }
        function refresh(): void {
            Hue.refresh();
        }
        function status(): string {
            return `${Hue.phase} ${Hue.onCount}/${Hue.lights.length}${Hue.stale ? " stale" : ""}`;
        }
    }

    // Calendar: the daemon is the shell's child, so a terminal reaches it
    // through here rather than by signalling a process it cannot see.
    IpcHandler {
        target: "calendar"

        function sync(): void {
            Calendar.lastSyncRequest = 0;
            Calendar.sync();
        }
        function login(): void {
            Calendar.login();
        }
        function logout(): void {
            Calendar.logout();
        }
        function join(): void {
            Calendar.join(Calendar.nextEvent);
        }
        // add "Title" "2026-09-10 09:00" 30 — a local event from a script.
        // A date alone makes it all-day.
        function add(title: string, when: string, minutes: int): void {
            const w = when.trim();
            if (w.length <= 10) {
                Calendar.create({
                    title: title,
                    allDay: true,
                    date: w,
                    days: 1
                });
                return;
            }
            const t = new Date(w.replace(" ", "T"));
            const end = new Date(t.getTime() + Math.max(5, minutes || 30) * 60000);
            Calendar.create({
                title: title,
                date: Qt.formatDate(t, "yyyy-MM-dd"),
                startTime: Qt.formatTime(t, "HH:mm"),
                endTime: Qt.formatTime(end, "HH:mm")
            });
        }
        // Open the calendar with the editor on today, for a keybind.
        function newEvent(): void {
            Popouts.open("calendar", null);
            Calendar.openEditor(new Date());
        }
        function next(): string {
            const e = Calendar.nextEvent;
            return e ? `${Calendar.relative(e.startMs)} ${Calendar.timeOf(e.startMs)} ${e.title}` : "";
        }
        function status(): string {
            return `${Calendar.phase} events=${Calendar.events.length} synced=${Calendar.lastSync} restarts=${Calendar.crashes}${Calendar.error !== "" ? " error=" + Calendar.error : ""}`;
        }
    }

    IpcHandler {
        target: "timer"

        // `qs -c ionix ipc call timer start 300` — seconds; 0 reuses the last length.
        function start(seconds: int): void {
            Countdown.start(seconds > 0 ? seconds : undefined);
        }
        function toggle(): void {
            Countdown.toggle();
        }
        function reset(): void {
            Countdown.reset();
        }
        function dismiss(): void {
            Countdown.dismiss();
        }
        function status(): string {
            return `${Countdown.phase} ${Countdown.format(Countdown.remaining)}`;
        }
    }

    IpcHandler {
        target: "popout"

        function toggle(name: string): void {
            Popouts.toggle(name, null);
        }
        function open(name: string): void {
            Popouts.open(name, null);
        }
        function close(): void {
            Popouts.close();
        }
        function current(): string {
            return Popouts.current;
        }
    }

    IpcHandler {
        target: "start"

        function toggle(): void {
            if (Config.start.opens === "appgrid")
                AppGrid.toggle();
            else
                Popouts.toggle("start", null);
        }
        function open(): void {
            Popouts.open("start", null);
        }
        function close(): void {
            Popouts.close();
        }
    }

    IpcHandler {
        target: "notifications"

        function toggle(): void {
            Popouts.toggle("notifications", null);
        }
        function dnd(): bool {
            Notifications.toggleDnd();
            return Notifications.dnd;
        }
        function clear(): void {
            Notifications.clearAll();
        }
        function count(): int {
            return Notifications.count;
        }
    }

    // The Alt+Tab binds land here, one call per Tab press — the overlay itself
    // never sees Tab, the compositor bind consumes it. commit exists for the
    // Alt-release bind and must stay a cheap no-op when nothing is open; peek
    // and status are for driving a session from a terminal while developing.
    // (peek, not show: `show` is the qs ipc CLI's own listing verb, and calling
    // a function by that name prints the handler listing instead.)
    IpcHandler {
        target: "switcher"

        function next(): void {
            WindowSwitcher.next();
        }
        function prev(): void {
            WindowSwitcher.prev();
        }
        function commit(): void {
            WindowSwitcher.commit();
        }
        function cancel(): void {
            WindowSwitcher.cancel();
        }
        function peek(): void {
            WindowSwitcher.open();
        }
        function list(): string {
            return WindowSwitcher.buildWindows().map(t => `${t.address} wl=${t.wayland ? "y" : "n"} mapped=${t.lastIpcObject?.mapped} act=${t.activated} urg=${WindowSwitcher.isUrgent(t)} ${Windows.appId(t)} | ${t.title}`).join("\n");
        }
        function status(): string {
            return `active=${WindowSwitcher.active} selection=${WindowSwitcher.selection}/${WindowSwitcher.windows.length} mru=${WindowSwitcher.mru.length}`;
        }
    }

    // Project workspaces (services/Projects.qml). The CLI calls refresh after
    // every save, rename and delete; open and saveDialog are for the binds and
    // land the start menu on its Projects page.
    IpcHandler {
        target: "projects"

        function refresh(): void {
            Projects.refresh();
        }
        function open(): void {
            Popouts.startView = "projects";
            Popouts.open("start", null);
        }
        function saveDialog(): void {
            Popouts.startView = "projects-save";
            Popouts.open("start", null);
        }
        function load(name: string): void {
            Projects.focusOrLoad(name);
        }
        function save(name: string): void {
            Projects.save(name);
        }
        function list(): string {
            return Projects.list.map(p => p.name).join("\n");
        }
        function current(): string {
            return Projects.current;
        }
    }

    IpcHandler {
        target: "appgrid"

        function toggle(): void {
            AppGrid.toggle();
        }
    }

    IpcHandler {
        target: "shortcuts"

        function toggle(): void {
            Shortcuts.toggle();
        }
    }

    IpcHandler {
        target: "taskview"

        function toggle(): void {
            TaskView.toggle();
        }
    }

    IpcHandler {
        target: "theme"

        function reload(): void {
            Config.reloadAll();
        }
    }

    IpcHandler {
        target: "shell"

        function reload(): void {
            Quickshell.reload(true);
        }
    }
}
