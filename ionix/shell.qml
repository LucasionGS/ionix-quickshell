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
