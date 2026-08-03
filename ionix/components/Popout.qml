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
import qs.services

PopupWindow {
    id: root

    default property alias content: panel.content
    property Item anchorItem: null
    property bool shouldOpen: false
    property int panelWidth: 340
    property int padding: Theme.sp6

    // How tall a growing list inside a panel may get before it scrolls instead.
    // Half the screen, so no popout can swallow the desktop however many wi-fi
    // networks or bluetooth devices happen to be in range.
    //
    // Measured from the *screen*, never from the panel: GlassPanel sizes itself
    // from childrenRect and this window binds implicitHeight to that, so anything
    // in here deriving its height from the panel would close the loop.
    readonly property int maxContentHeight: Math.round((root.screen?.height ?? 1080) * 0.5)

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


    // Dismissal must go through Popouts, never through `shouldOpen = false`:
    // callers bind shouldOpen to Popouts.isOpen(...), and assigning to it would
    // overwrite that binding with a constant. The panel would then close once and
    // never reopen, because nothing re-evaluates when Popouts.current changes.
    HyprlandFocusGrab {
        active: root.shouldOpen
        windows: [root]
        onCleared: Popouts.close()
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
        onActivated: Popouts.close()
    }
}
