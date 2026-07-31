// A small uppercase divider label with an optional control on the right.
// The start menu stacks five of these; the other popouts inline the same Text.

import QtQuick
import qs.config

Item {
    id: root

    property string text: ""
    property string glyph: ""
    // Right-hand slot: a toggle, a count, a "see all" button.
    default property alias trailing: trailingHolder.data

    implicitWidth: 200
    implicitHeight: 20

    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.sp2

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.glyph !== ""
            text: root.glyph
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsSm
            color: Theme.accentLight
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text.toUpperCase()
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsXs
            font.weight: Font.DemiBold
            // Wide tracking is what makes a 9px label read as a section rule
            // rather than as small body text.
            font.letterSpacing: 1.2
            color: Theme.muted
        }
    }

    Item {
        id: trailingHolder
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
        width: implicitWidth
        height: implicitHeight
    }
}
