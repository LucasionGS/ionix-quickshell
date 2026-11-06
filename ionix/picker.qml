// Ionix share picker — the fourth entry point in this tree, next to shell.qml,
// lock.qml and greeter.qml.
//
// xdg-desktop-portal-hyprland runs a picker whenever an app asks to capture the
// screen (Discord, a browser, OBS) and waits for its answer. `ionix-share-picker`
// is that picker: it runs this file as its own Quickshell process (qs -p), so a
// bar crash cannot take the dialog with it and the capture streams behind the
// previews end when the process does. Living in the shell's tree is what gives
// it the live theme through qs.config.
//
// Nothing here reaches Notifications or any other service that must only run
// once per session.
//
// Environment (set by bin/ionix-share-picker):
//   IONIX_PICKER_OUT          file the answer is written to
//   IONIX_PICKER_ALLOW_TOKEN  1 when xdph passed --allow-token
//   IONIX_PICKER_MONITOR      the focused monitor, where the dialog opens
//   XDPH_WINDOW_SHARING_LIST  xdph's own list of windows it can share
//   IONIX_PICKER_DEV=1        hot-reload while it is up (for working on it)

import QtQuick
import Quickshell
import qs.picker

ShellRoot {
    Component.onCompleted: {
        // A package upgrade landing while the dialog is open must not reload it.
        Quickshell.watchFiles = Quickshell.env("IONIX_PICKER_DEV") === "1";
    }

    // Made once the monitor it opens on is known: a PanelWindow's screen is
    // fixed when it maps.
    LazyLoader {
        active: PickerState.hostScreen !== null

        PickerWindow {}
    }

    Variants {
        model: Quickshell.screens

        RegionWindow {}
    }
}
