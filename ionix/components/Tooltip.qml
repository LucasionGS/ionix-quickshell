// A delayed hover tooltip.
//
// Uses a PopupWindow rather than an in-bar Item because the bar is a layer-shell
// surface with a fixed height — anything drawn below the bar would be clipped.

import QtQuick
import Quickshell
import qs.config

PopupWindow {
    id: root

    property string text: ""
    property Item target: null
    property bool shown: false
    property int delay: 450

    // Keep the window alive briefly after `shown` drops so the fade-out can play.
    visible: (root.shown && root.text !== "" && armed) || fadeOut.running
    property bool armed: false

    anchor.item: root.target
    anchor.gravity: Edges.Bottom
    anchor.edges: Edges.Bottom
    anchor.margins.top: Theme.sp2

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
        onTriggered: root.armed = true
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
        y: root.armed && root.shown ? 0 : -4

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
