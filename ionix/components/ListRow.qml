// A selectable row: leading glyph or icon, title, optional subtitle, trailing slot.
// Every popout list (sinks, Wi-Fi networks, bluetooth devices) is built from these.

import QtQuick
import Quickshell.Widgets
import qs.config

Rectangle {
    id: root

    property string icon: ""            // Nerd Font glyph
    property string iconSource: ""      // freedesktop icon name, wins over `icon`
    property string title: ""
    property string subtitle: ""
    property color iconColour: Theme.accentLight
    property bool selected: false
    property bool busy: false
    // Trailing content (switches, badges, buttons).
    default property alias trailing: trailingHolder.data

    readonly property bool hovered: mouse.containsMouse

    signal clicked
    signal rightClicked

    implicitWidth: 200
    implicitHeight: Math.max(40, textCol.implicitHeight + Theme.sp3 * 2)

    radius: Theme.rSm
    color: root.selected ? Theme.alpha(Theme.accentBright, 0.16) : (root.hovered ? Theme.alpha(Theme.hover, 0.5) : "transparent")
    border.width: 1
    border.color: root.selected ? Theme.alpha(Theme.accentBright, 0.3) : "transparent"

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

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: event => {
            if (event.button === Qt.RightButton)
                root.rightClicked();
            else
                root.clicked();
        }
    }

    Item {
        id: iconSlot
        anchors.left: parent.left
        anchors.leftMargin: Theme.sp3
        anchors.verticalCenter: parent.verticalCenter
        width: 22
        height: 22

        Text {
            anchors.centerIn: parent
            visible: root.iconSource === ""
            text: root.icon
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsIcon
            color: root.selected ? Theme.accentBright : root.iconColour
        }

        IconImage {
            anchors.fill: parent
            visible: root.iconSource !== ""
            source: root.iconSource
            asynchronous: true
        }

        // Indeterminate spinner for in-flight connect/pair operations.
        Rectangle {
            anchors.centerIn: parent
            visible: root.busy
            width: 20
            height: 20
            radius: 10
            color: "transparent"
            border.width: 2
            border.color: Theme.alpha(Theme.accentBright, 0.35)

            Rectangle {
                width: 4
                height: 4
                radius: 2
                color: Theme.accentBright
                x: parent.width - 4
                y: parent.height / 2 - 2
            }

            RotationAnimation on rotation {
                running: root.busy
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 900
            }
        }
    }

    Column {
        id: textCol
        anchors.left: iconSlot.right
        anchors.leftMargin: Theme.sp3
        anchors.right: trailingHolder.left
        anchors.rightMargin: Theme.sp2
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            text: root.title
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsMd
            font.weight: root.selected ? Font.DemiBold : Font.Normal
            color: root.selected ? Theme.textBright : Theme.text
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: root.subtitle !== ""
            text: root.subtitle
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsXs
            color: Theme.muted
            elide: Text.ElideRight
        }
    }

    Item {
        id: trailingHolder
        anchors.right: parent.right
        anchors.rightMargin: Theme.sp3
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
        width: implicitWidth
        height: implicitHeight
    }
}
