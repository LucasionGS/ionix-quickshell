// Alt+Tab window switcher overlay.
//
// Lives in osd/ for the same reason NotificationToasts does: an overlay window,
// never loadable as a bar module. It is also the tree's only *fullscreen* layer
// surface — everything else is edge-anchored — because a switcher is modal on
// its monitor: the whole surface is a click target (empty area cancels), so no
// input mask.
//
// Keyboard focus is the load-bearing part. Tab presses never reach us — the
// compositor binds consume them and arrive as IPC calls — but the Alt *release*
// must, so while a session is open this surface holds an Exclusive grab; the
// still-held Alt keycode is in the wl_keyboard.enter array, which makes its
// release a real key event to us. The grab is bound to the session, not to
// `visible`: the surface stays mapped through the exit fade, and holding focus
// that long would steal the very focus the committed window needs (the
// ShellFocus trap — Hyprland won't focus a window while a layer surface holds
// the keyboard).

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services

PanelWindow {
    id: root

    required property var modelData
    screen: root.modelData

    // The session pins its monitor at open(); only that overlay shows anything.
    readonly property bool isTarget: WindowSwitcher.monitor === root.modelData.name
    readonly property bool showing: WindowSwitcher.active && root.isTarget

    WlrLayershell.namespace: "ionix-switcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    visible: root.showing || fadeHold.running
    focusable: root.showing
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Keep the surface mapped long enough for the exit animation to finish.
    Timer {
        id: fadeHold
        interval: Theme.durFast
    }

    onShowingChanged: {
        if (!root.showing) {
            fadeHold.restart();
            return;
        }
        // Deferred like StartPopout's search field: the surface has not taken
        // keyboard focus yet at the moment the binding flips.
        Qt.callLater(() => keys.forceActiveFocus());
    }

    // Dimmed backdrop; also the click-to-cancel target. Kept below the blur
    // rule's ignore_alpha threshold so the compositor doesn't blur the whole
    // screen, only the panel.
    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.bgDeep, 0.18)
        opacity: root.showing ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: root.showing ? Theme.durSlide : Theme.durFast
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: WindowSwitcher.cancel()
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (!root.showing)
                return;
            switch (event.key) {
            case Qt.Key_Escape:
                WindowSwitcher.cancel();
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                WindowSwitcher.commit();
                break;
            case Qt.Key_Left:
            case Qt.Key_Up:
                WindowSwitcher.cycle(-1);
                break;
            case Qt.Key_Right:
            case Qt.Key_Down:
                WindowSwitcher.cycle(1);
                break;
            default:
                return;
            }
            event.accepted = true;
        }

        Keys.onReleased: event => {
            // Only the Alt release commits — Shift comes up first in a
            // Shift+Alt+Tab gesture and must not end the session.
            if (root.showing && event.key === Qt.Key_Alt && !event.isAutoRepeat) {
                WindowSwitcher.commit();
                event.accepted = true;
            }
        }
    }

    GlassPanel {
        id: panel

        // Cards per row, capped by the configured fraction of the screen; the
        // Flow wraps the rest into further rows, Windows 11 style.
        readonly property int cardCell: Config.windowSwitcher.cardWidth + Theme.sp3
        readonly property int maxCols: Math.max(1, Math.floor((root.width * Config.windowSwitcher.maxWidthFraction - padding * 2 + Theme.sp3) / cardCell))
        readonly property int cols: Math.max(1, Math.min(WindowSwitcher.windows.length, maxCols))

        anchors.centerIn: parent
        width: panel.cols * Config.windowSwitcher.cardWidth + (panel.cols - 1) * Theme.sp3 + padding * 2

        opacity: root.showing ? 1 : 0
        scale: root.showing ? 1 : 0.94

        Behavior on opacity {
            NumberAnimation {
                duration: root.showing ? Theme.durSlide : Theme.durFast
                easing.type: root.showing ? Theme.easeStandard : Theme.easeIn
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: root.showing ? Theme.durSlide : Theme.durFast
                easing.type: root.showing ? Theme.easeStandard : Theme.easeIn
            }
        }

        Flow {
            width: panel.width - panel.padding * 2
            spacing: Theme.sp3

            Repeater {
                model: WindowSwitcher.windows

                delegate: WindowPreviewCard {
                    required property var modelData
                    required property int index

                    toplevel: modelData
                    selected: index === WindowSwitcher.selection
                    onActivated: {
                        WindowSwitcher.select(index);
                        WindowSwitcher.commit();
                    }
                }
            }
        }
    }
}
