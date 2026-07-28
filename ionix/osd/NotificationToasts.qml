// Notification toasts.
//
// Lives here rather than in modules/ because it's an overlay window like the OSD,
// not a bar widget — anything in modules/ can be named in Config.modules and
// loaded into the bar, which this must never be.
//
// One instance per screen (see shell.qml), but only the target screen ever shows
// anything: duplicating every toast across four monitors is noise, not redundancy.
// The window is Overlay layer with exclusion ignored, so toasts float over
// fullscreen windows and never reserve space; it sits below the bar by adding the
// bar's height back manually, which ExclusionMode.Ignore opts out of.

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

PanelWindow {
    id: root

    required property var modelData
    screen: root.modelData

    readonly property int cardWidth: Config.notifications.width ?? 380
    readonly property bool barAtTop: Config.bar.position !== "bottom"

    // "" follows the focused monitor, which is where you're looking; a name pins
    // toasts to one screen.
    readonly property bool isTarget: {
        const want = Config.notifications.monitor ?? "";
        if (want !== "")
            return root.modelData.name === want;
        const focused = Hyprland.focusedMonitor?.name;
        // Hyprland may not have reported a focused monitor yet at startup; falling
        // back to the first screen keeps an early notification from vanishing.
        if (!focused)
            return Quickshell.screens[0]?.name === root.modelData.name;
        return focused === root.modelData.name;
    }

    WlrLayershell.namespace: "ionix-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    // Toasts are click targets but never text inputs, and taking keyboard focus
    // from a fullscreen app to show one would be hostile.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    visible: root.isTarget && Notifications.popups.length > 0
    focusable: false
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: root.barAtTop
        bottom: !root.barAtTop
        right: true
    }

    margins {
        top: root.barAtTop ? root.barOffset : 0
        bottom: root.barAtTop ? 0 : root.barOffset
        right: (Config.bar.floating ? Config.bar.margin.right : 0) + Theme.sp3
    }

    // The bar's exclusive zone doesn't apply to us, so clear it by hand.
    readonly property int barOffset: (Config.bar.floating ? Config.bar.margin.top : 0) + Config.bar.height + Theme.sp3

    implicitWidth: root.cardWidth
    implicitHeight: Math.max(1, column.implicitHeight)

    // Only the cards take pointer input — without this the window's full rectangle
    // would swallow clicks aimed at whatever is behind the gaps between toasts.
    mask: Region {
        item: column
    }

    Column {
        id: column
        width: root.cardWidth
        spacing: Theme.sp2

        // Closing one toast should slide the others up rather than teleport them.
        move: Transition {
            NumberAnimation {
                properties: "y"
                duration: Theme.durSlide
                easing.type: Theme.easeStandard
            }
        }

        Repeater {
            model: Notifications.popups

            delegate: Item {
                id: slot

                required property var modelData

                readonly property int duration: Notifications.popupDuration(slot.modelData)

                width: column.width
                height: card.implicitHeight

                // Drawn as a sibling rather than inside the card: a Rectangle
                // paints its own fill before any child, so a shadow parented to
                // the card could never sit behind it.
                RectangularShadow {
                    anchors.fill: card
                    radius: card.radius
                    blur: 32
                    spread: 0
                    offset: Qt.vector2d(0, 6)
                    color: Qt.rgba(0, 0, 0, 0.55)
                    opacity: card.opacity
                }

                NotificationCard {
                    id: card

                    width: parent.width
                    notification: slot.modelData
                    bodyLines: 4
                    elevated: true
                    showLife: slot.duration > 0

                    // Slide in from off the right edge.
                    x: slot.entered ? 0 : parent.width + Theme.sp3
                    opacity: slot.entered ? 1 : 0

                    Behavior on x {
                        NumberAnimation {
                            duration: Theme.durSlide
                            easing.type: Theme.easeStandard
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durSlide
                        }
                    }
                }

                property bool entered: false
                Component.onCompleted: slot.entered = true

                // The countdown bar is the timer: driving both from one animation
                // means "paused while hovered" needs no second piece of state.
                NumberAnimation {
                    target: card
                    property: "lifeWidth"
                    from: card.width
                    to: 0
                    duration: slot.duration
                    running: slot.duration > 0 && card.width > 0
                    paused: card.hovered
                    onFinished: Notifications.hidePopup(slot.modelData)
                }
            }
        }
    }
}
