// The accent blob that slides between active items.
//
// Shared by Workspaces (pill behind the active workspace) and Taskbar (underline
// beneath the focused window). Animating one shape between positions reads far
// better than fading a border in and out on each item, and it's one item to draw
// instead of N.

import QtQuick
import qs.config

Rectangle {
    id: root

    // Geometry of the item to track, in the parent's coordinate space. All four
    // are stated by the caller — the blob slides along the bar's long axis and
    // spans its short one, and which is which depends on the bar's orientation.
    property real targetX: 0
    property real targetY: 0
    property real targetWidth: 0
    property real targetHeight: 0
    property bool vertical: false
    property bool active: true
    property color colourStart: Theme.accentBright
    property color colourEnd: Theme.link

    x: root.targetX
    y: root.targetY
    width: root.targetWidth
    height: root.targetHeight
    opacity: root.active && root.targetWidth > 0 && root.targetHeight > 0 ? 1 : 0
    radius: Math.min(width, height) / 2

    gradient: Gradient {
        orientation: root.vertical ? Gradient.Vertical : Gradient.Horizontal
        GradientStop {
            position: 0.0
            color: Theme.alpha(root.colourStart, 0.30)
        }
        GradientStop {
            position: 1.0
            color: Theme.alpha(root.colourEnd, 0.30)
        }
    }

    border.width: 1
    border.color: Theme.alpha(root.colourStart, 0.45)

    Behavior on x {
        NumberAnimation {
            duration: Theme.durSlide
            easing.type: Theme.easeStandard
        }
    }
    Behavior on y {
        NumberAnimation {
            duration: Theme.durSlide
            easing.type: Theme.easeStandard
        }
    }
    Behavior on width {
        NumberAnimation {
            duration: Theme.durSlide
            easing.type: Theme.easeStandard
        }
    }
    Behavior on height {
        NumberAnimation {
            duration: Theme.durSlide
            easing.type: Theme.easeStandard
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durFast
        }
    }

    // Outer glow.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        z: -1
        radius: parent.radius + 3
        color: "transparent"
        border.width: 3
        border.color: Theme.alpha(root.colourStart, 0.12)
    }
}
