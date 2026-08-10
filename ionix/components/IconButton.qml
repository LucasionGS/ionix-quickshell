// A glyph button with hover scale, colour transitions and an optional tooltip.
// The workhorse of the bar — every clickable indicator is one of these.
//
// `vertical` turns it for a left/right bar: glyph and label stack instead of
// sitting side by side, the padding follows the long axis, and the tooltip moves
// to the side. It defaults to false rather than reading Config.barVertical
// because these are used inside popout panels too, which never turn.

import QtQuick
import qs.config

Item {
    id: root

    property string icon: ""
    property string label: ""
    property color colour: Theme.text
    property color hoverColour: Theme.textBright
    property int fontSize: Theme.fsIcon
    // Overridable so the launcher can use the Ionix logo font for its glyph.
    property string fontFamily: Theme.fontFamily
    property string tooltip: ""
    property int horizontalPadding: Theme.sp3
    property bool glow: true
    property bool active: false
    property bool vertical: false
    // Extra content drawn over the glyph (badges, level bars).
    default property alias overlay: overlayHolder.data

    readonly property bool hovered: mouse.containsMouse

    signal clicked
    signal rightClicked
    signal middleClicked
    signal scrolled(int delta)

    // horizontalPadding pads the axis the button grows along, whichever that is;
    // the other axis is always the bar's pill thickness.
    readonly property int extent: (root.vertical ? content.implicitHeight : content.implicitWidth) + root.horizontalPadding * 2

    implicitWidth: root.vertical ? Theme.pillHeight : root.extent
    implicitHeight: root.vertical ? root.extent : Theme.pillHeight

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: root.vertical ? 0 : 2
        anchors.bottomMargin: root.vertical ? 0 : 2
        anchors.leftMargin: root.vertical ? 2 : 0
        anchors.rightMargin: root.vertical ? 2 : 0
        radius: Theme.rSm
        color: root.hovered ? Theme.alpha(root.colour, 0.12) : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Theme.durNormal
            }
        }
    }

    // Grid rather than Row: it is the one positioner that can be a row or a
    // column, and its own item alignment replaces the per-child verticalCenter
    // anchors a Row needed.
    Grid {
        id: content
        anchors.centerIn: parent
        rows: root.vertical ? 2 : 1
        columns: root.vertical ? 1 : 2
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
        spacing: root.label !== "" && root.icon !== "" ? Theme.sp2 : 0
        scale: root.hovered ? 1.08 : 1.0

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durFast
                easing.type: Theme.easeOvershoot
            }
        }

        Text {
            visible: root.icon !== ""
            text: root.icon
            font.family: root.fontFamily
            font.pixelSize: root.fontSize
            color: root.hovered || root.active ? root.hoverColour : root.colour

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durNormal
                }
            }
        }

        Text {
            visible: root.label !== ""
            text: root.label
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsMd
            font.weight: Font.DemiBold
            color: root.hovered || root.active ? root.hoverColour : root.colour

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durNormal
                }
            }
        }
    }

    Item {
        id: overlayHolder
        anchors.fill: parent
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        onClicked: event => {
            if (event.button === Qt.LeftButton)
                root.clicked();
            else if (event.button === Qt.RightButton)
                root.rightClicked();
            else if (event.button === Qt.MiddleButton)
                root.middleClicked();
        }

        onWheel: event => {
            root.scrolled(event.angleDelta.y > 0 ? 1 : -1);
            event.accepted = true;
        }
    }

    Tooltip {
        text: root.tooltip
        target: root
        sideways: root.vertical
        shown: root.hovered && root.tooltip !== ""
    }
}
