// A rounded translucent container that groups related bar widgets.
// Sizes itself to its content; set `accent` to give it a coloured glow.

import QtQuick
import qs.config

Rectangle {
    id: root

    default property alias content: layout.data
    property alias spacing: layout.spacing
    property int padding: Theme.sp2
    property bool accented: false
    property color accentColour: Theme.accentBright
    property bool interactive: false
    property bool hovered: false

    implicitWidth: layout.implicitWidth + padding * 2
    implicitHeight: Theme.pillHeight

    radius: Theme.rPill
    color: root.accented ? Theme.alpha(root.accentColour, 0.12) : (root.interactive && root.hovered ? Theme.alpha(Theme.hover, 0.55) : Theme.pillFill)
    border.width: 1
    border.color: root.accented ? Theme.alpha(root.accentColour, 0.35) : Theme.pillBorder

    Behavior on color {
        ColorAnimation {
            duration: Theme.durNormal
        }
    }
    Behavior on border.color {
        ColorAnimation {
            duration: Theme.durNormal
        }
    }

    Row {
        id: layout
        anchors.centerIn: parent
        spacing: 0
    }

    // Soft outer glow, only paid for when accented.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -2
        z: -1
        radius: parent.radius + 2
        color: "transparent"
        border.width: 2
        border.color: Theme.alpha(root.accentColour, root.accented ? 0.10 : 0)
        visible: root.accented

        Behavior on border.color {
            ColorAnimation {
                duration: Theme.durNormal
            }
        }
    }
}
