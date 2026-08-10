// A rounded translucent container that groups related bar widgets.
// Sizes itself to its content; set `accent` to give it a coloured glow.
//
// `vertical` stacks its children instead of lining them up, for a left/right bar.
// The inner positioner is a Grid because that is the only one that can be either,
// and its item alignment does what a Row's per-child verticalCenter anchors used
// to — so children must not anchor themselves inside a Pill.

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
    property bool vertical: false

    // Grid needs a real limit on one axis to know which way it runs. Counting all
    // children rather than the visible ones is deliberate: `children` notifies,
    // `visibleChildren` does not, and an over-count only leaves empty cells —
    // Grid skips invisible items when it places the rest.
    readonly property int slots: Math.max(1, layout.children.length)

    // The cross axis is the pill thickness, the long axis follows the content —
    // mirrored when vertical. The max() is a floor, not a size: content wider than
    // the bar overflows rather than being clipped, which is easier to notice.
    implicitWidth: root.vertical ? Math.max(Theme.pillHeight, layout.implicitWidth + padding * 2) : layout.implicitWidth + padding * 2
    implicitHeight: root.vertical ? layout.implicitHeight + padding * 2 : Theme.pillHeight

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

    Grid {
        id: layout
        anchors.centerIn: parent
        rows: root.vertical ? root.slots : 1
        columns: root.vertical ? 1 : root.slots
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
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
