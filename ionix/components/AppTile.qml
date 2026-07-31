// A square application tile: icon over a two-line label.
//
// ListRow is the horizontal equivalent and shares its hover/selected colours; the
// difference is only orientation, and a grid of rows reads badly at tile sizes.

import QtQuick
import Quickshell.Widgets
import qs.config

Rectangle {
    id: root

    property string iconSource: ""      // resolved path, "" falls back to the initial
    property string label: ""
    property string fallbackGlyph: ""
    property int iconSize: 40
    property bool selected: false
    property bool running: false

    readonly property bool hovered: mouse.containsMouse

    signal clicked
    signal rightClicked

    implicitWidth: 90
    implicitHeight: root.iconSize + Theme.sp5 * 2 + 26

    radius: Theme.rPill
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

    Item {
        id: iconSlot
        anchors.top: parent.top
        anchors.topMargin: Theme.sp4
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.iconSize
        height: root.iconSize

        scale: root.hovered ? 1.1 : 1.0

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durFast
                easing.type: Theme.easeOvershoot
            }
        }

        IconImage {
            anchors.fill: parent
            visible: root.iconSource !== ""
            source: root.iconSource
            asynchronous: true
        }

        // Placeholder for apps whose .desktop names an icon the theme lacks. A
        // tinted initial reads as deliberate; a broken-image glyph does not.
        Rectangle {
            anchors.fill: parent
            visible: root.iconSource === ""
            radius: Theme.rSm
            color: Theme.alpha(Theme.accent, 0.25)
            border.width: 1
            border.color: Theme.alpha(Theme.accentBright, 0.3)

            Text {
                anchors.centerIn: parent
                text: root.fallbackGlyph !== "" ? root.fallbackGlyph : root.label.charAt(0).toUpperCase()
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(root.iconSize * 0.45)
                font.weight: Font.DemiBold
                color: Theme.accentLight
            }
        }
    }

    Text {
        anchors.top: iconSlot.bottom
        anchors.topMargin: Theme.sp3
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.sp2
        anchors.rightMargin: Theme.sp2
        horizontalAlignment: Text.AlignHCenter
        text: root.label
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fsXs
        color: root.selected || root.hovered ? Theme.textBright : Theme.text
        elide: Text.ElideRight
        maximumLineCount: 2
        wrapMode: Text.Wrap
    }

    // Running marker, mirroring the taskbar's convention.
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Theme.sp3
        visible: root.running
        width: 5
        height: 5
        radius: 2.5
        color: Theme.accentBright
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
}
