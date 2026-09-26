// Now playing, for the bottom of the lock screen: art, title, artist and the
// three transport buttons. Controlling playback without unlocking is the one
// thing everyone expects a lock screen to allow.

import QtQuick
import Quickshell.Widgets
import qs.config
import qs.services

Rectangle {
    id: root

    implicitHeight: 60
    height: implicitHeight
    radius: Theme.rPanel
    color: Theme.alpha(Theme.bgWindow, 0.55)
    border.width: 1
    border.color: Theme.alpha(Theme.accentBright, 0.18)

    ClippingRectangle {
        id: art
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 44
        height: 44
        radius: Theme.rSm + 2
        color: Theme.alpha(Theme.accent, 0.25)

        Text {
            anchors.centerIn: parent
            visible: artImage.status !== Image.Ready
            text: Icons.music
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsIconLg
            color: Theme.accentLight
        }

        Image {
            id: artImage
            anchors.fill: parent
            source: Player.artUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 88
            sourceSize.height: 88
        }
    }

    Column {
        anchors.left: art.right
        anchors.leftMargin: Theme.sp4
        anchors.right: controls.left
        anchors.rightMargin: Theme.sp3
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            text: Player.title !== "" ? Player.title : Player.identity
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsBase
            font.weight: Font.DemiBold
            color: Theme.textBright
        }

        Text {
            width: parent.width
            visible: text !== ""
            text: Player.artist
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsSm
            color: Theme.muted
        }
    }

    Row {
        id: controls
        anchors.right: parent.right
        anchors.rightMargin: Theme.sp3
        anchors.verticalCenter: parent.verticalCenter

        spacing: Theme.sp1

        LockButton {
            size: 34
            icon: Icons.prev
            onClicked: Player.previous()
        }
        LockButton {
            size: 40
            icon: Player.playing ? Icons.pause : Icons.play
            fontSize: 22
            colour: Theme.accentLight
            onClicked: Player.toggle()
        }
        LockButton {
            size: 34
            icon: Icons.next
            onClicked: Player.next()
        }
    }
}
