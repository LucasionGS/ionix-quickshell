// A dismissable panel anchored under a bar item.
//
// Dismissal uses HyprlandFocusGrab, which is what makes click-outside work on a
// layer-shell surface — there is no "outside" MouseArea to catch on a compositor
// where the popup is its own window.
//
// The window stays mapped for durFast after `shouldOpen` drops so the exit
// animation has something to play on; closeHold is what keeps it alive.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config

PopupWindow {
    id: root

    default property alias content: panel.content
    property Item anchorItem: null
    property bool shouldOpen: false
    property int panelWidth: 340
    property int padding: Theme.sp6

    visible: root.shouldOpen || closeHold.running
    color: "transparent"
    // Take keyboard focus so Escape and text fields work inside the panel.
    grabFocus: root.shouldOpen

    anchor.item: root.anchorItem
    anchor.gravity: Edges.Bottom
    anchor.edges: Edges.Bottom
    anchor.margins.top: Theme.sp2
    // Slide back onto the screen instead of overflowing when a right-hand module
    // opens a panel wider than the space left beside it.
    anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.FlipY

    implicitWidth: root.panelWidth
    implicitHeight: panel.implicitHeight

    onShouldOpenChanged: {
        if (!root.shouldOpen)
            closeHold.restart();
    }

    Timer {
        id: closeHold
        interval: Theme.durFast
    }


    HyprlandFocusGrab {
        active: root.shouldOpen
        windows: [root]
        onCleared: root.shouldOpen = false
    }

    GlassPanel {
        id: panel
        width: root.panelWidth
        padding: root.padding

        opacity: root.shouldOpen ? 1 : 0
        scale: root.shouldOpen ? 1 : 0.94
        y: root.shouldOpen ? 0 : 8
        transformOrigin: Item.Top

        Behavior on opacity {
            NumberAnimation {
                duration: root.shouldOpen ? Theme.durSlide : Theme.durFast
                easing.type: root.shouldOpen ? Theme.easeStandard : Theme.easeIn
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: root.shouldOpen ? Theme.durSlide : Theme.durFast
                easing.type: root.shouldOpen ? Theme.easeStandard : Theme.easeIn
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: root.shouldOpen ? Theme.durSlide : Theme.durFast
                easing.type: root.shouldOpen ? Theme.easeStandard : Theme.easeIn
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.shouldOpen
        onActivated: root.shouldOpen = false
    }
}
