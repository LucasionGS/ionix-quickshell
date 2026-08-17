// Ionix Quickshell — entry point.
//
// System defaults live in /etc/xdg/quickshell/ionix. User overrides go in
// ~/.config/quickshell/ionix/config.json — see the README for why that path is
// safe despite sharing this directory's name.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules
import qs.osd
import qs.services

ShellRoot {
    id: root

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
