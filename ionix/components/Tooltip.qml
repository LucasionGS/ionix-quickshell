// A delayed hover tooltip.
//
// Uses a PopupWindow rather than an in-bar Item because the bar is a layer-shell
// surface with a fixed height — anything drawn below the bar would be clipped.
//
// The bubble sits below its target in the top half of the monitor and above it in
// the bottom half, so it always grows towards the middle of the screen. Fixed
// placement put it under the pointer whenever the target was low down — covering
// whatever the pointer was about to move onto — and ran it off the bottom edge
// entirely for a bar-at-bottom layout.
//
// `sideways` is the same idea rotated, for items in a vertical bar: the bubble
// goes to whichever side the bar is not docked to, since above/below would land
// it on the neighbouring module.

import QtQuick
import Quickshell
import qs.config
import qs.services

PopupWindow {
    id: root

    property string text: ""
    property Item target: null
    property bool shown: false
    property int delay: 450
    // Place beside the target rather than above/below it.
    property bool sideways: false

    // Which side that is: away from the docked edge, so the bubble grows into the
    // screen. Only read when `sideways`.
    readonly property bool toRight: Config.bar.position !== "right"

    // Keep the window alive briefly after `shown` drops so the fade-out can play.
    visible: (root.shown && root.text !== "" && armed) || fadeOut.running
    property bool armed: false

    // Decided once, when the bubble is about to appear, rather than bound: the
    // position depends on mapToItem(), which a binding cannot register as a
    // dependency, so a bound value would go stale the first time anything moved.
    property bool above: false

    // Input-transparent. A tooltip is never clicked, and one that swallowed
    // clicks would make whatever it covers unusable for as long as it is up —
    // which is the whole complaint the placement above is fixing.
    mask: Region {}

    readonly property int sideEdge: root.toRight ? Edges.Right : Edges.Left

    anchor.item: root.target
    anchor.gravity: root.sideways ? root.sideEdge : (root.above ? Edges.Top : Edges.Bottom)
    anchor.edges: root.sideways ? root.sideEdge : (root.above ? Edges.Top : Edges.Bottom)
    anchor.margins.top: (root.sideways || root.above) ? 0 : Theme.sp2
    anchor.margins.bottom: (!root.sideways && root.above) ? Theme.sp2 : 0
    anchor.margins.left: (root.sideways && root.toRight) ? Theme.sp2 : 0
    anchor.margins.right: (root.sideways && !root.toRight) ? Theme.sp2 : 0
    // Backstop for the cases Placement cannot resolve (a tooltip inside a plain
    // menu popup), where `above` stays false and the bubble could overflow.
    anchor.adjustment: root.sideways ? (PopupAdjustment.SlideY | PopupAdjustment.FlipX) : (PopupAdjustment.SlideX | PopupAdjustment.FlipY)

    implicitWidth: body.implicitWidth
    implicitHeight: body.implicitHeight
    color: "transparent"

    onShownChanged: {
        if (root.shown)
            armTimer.restart();
        else {
            armTimer.stop();
            if (armed)
                fadeOut.restart();
            armed = false;
        }
    }

    Timer {
        id: armTimer
        interval: root.delay
        onTriggered: {
            root.above = Placement.inLowerHalf(root.target);
            root.armed = true;
        }
    }

    Timer {
        id: fadeOut
        interval: Theme.durFast
    }

    Rectangle {
        id: body
        implicitWidth: Math.min(420, label.implicitWidth + Theme.sp4 * 2)
        implicitHeight: label.implicitHeight + Theme.sp3 * 2
        radius: Theme.rSm
        color: Theme.tooltipFill
        border.width: 1
        border.color: Theme.alpha(Theme.accentBright, 0.22)

        opacity: root.armed && root.shown ? 1 : 0
        // Slides out of the target, so the offset follows the side it is on.
        y: (root.armed && root.shown) || root.sideways ? 0 : (root.above ? 4 : -4)
        x: (root.armed && root.shown) || !root.sideways ? 0 : (root.toRight ? -4 : 4)

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durFast
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: Theme.durFast
                easing.type: Theme.easeStandard
            }
        }
        Behavior on x {
            NumberAnimation {
                duration: Theme.durFast
                easing.type: Theme.easeStandard
            }
        }

        Text {
            id: label
            anchors.centerIn: parent
            width: Math.min(400, implicitWidth)
            text: root.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsSm
            color: Theme.text
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
