// A glyph button with hover scale, colour transitions and an optional tooltip.
// The workhorse of the bar — every clickable indicator is one of these.

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
    // Extra content drawn over the glyph (badges, level bars).
    default property alias overlay: overlayHolder.data

    readonly property bool hovered: mouse.containsMouse

    signal clicked
    signal rightClicked
    signal middleClicked
    signal scrolled(int delta)

    implicitWidth: contentRow.implicitWidth + horizontalPadding * 2
    implicitHeight: Theme.pillHeight

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 2
        anchors.bottomMargin: 2
        radius: Theme.rSm
        color: root.hovered ? Theme.alpha(root.colour, 0.12) : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Theme.durNormal
            }
        }
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
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
            anchors.verticalCenter: parent.verticalCenter
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
            anchors.verticalCenter: parent.verticalCenter
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
        shown: root.hovered && root.tooltip !== ""
    }
}
