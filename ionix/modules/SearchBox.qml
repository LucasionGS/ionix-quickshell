// A search box on the bar. It only looks like an input: a click hands over to
// launcher.command, which is where searching really happens (ioexplorer-spotlight).
// A vertical bar has no room for one, so there it is just the magnifier.

import QtQuick
import qs.config
import qs.services

Item {
    id: root

    property var bar: null

    readonly property bool vertical: Config.barVertical
    implicitWidth: root.vertical ? 36 : Config.launcher.searchWidth ?? 240
    implicitHeight: 36

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: mouse.pressed ? Theme.subtlePressed : (mouse.containsMouse ? Theme.subtleHover : Theme.controlFill)
        border.width: 1
        border.color: Theme.controlStroke

        Behavior on color {
            ColorAnimation {
                duration: Theme.durFast
            }
        }
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: root.vertical ? (parent.width - Theme.fsIconLg) / 2 : Theme.sp4
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.sp3

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.search
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsIconLg
            color: Theme.textBright
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.vertical
            text: "Search"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsBase
            color: Theme.muted
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: Launch.run(Config.launcher.command)
    }
}
