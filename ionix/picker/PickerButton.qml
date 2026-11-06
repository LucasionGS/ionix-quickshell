// A text button for the share picker's footer and the region toolbar. `primary`
// is the accent-filled one that ends the dialog.

import QtQuick
import qs.config

Rectangle {
    id: root

    property string text: ""
    property string glyph: ""
    property bool primary: false
    property bool enabled: true
    // A keyboard hint drawn after the label, such as "Enter".
    property string hint: ""
    readonly property bool hovered: mouse.containsMouse

    signal clicked

    implicitWidth: row.implicitWidth + Theme.sp5 * 2
    implicitHeight: 34
    radius: Theme.rSm
    opacity: root.enabled ? 1 : 0.45
    color: {
        if (root.primary)
            return root.hovered && root.enabled ? Theme.accentLight : Theme.accentBright;
        return root.hovered && root.enabled ? Theme.subtleHover : Theme.controlFill;
    }
    border.width: root.primary ? 0 : 1
    border.color: Theme.controlStroke

    Behavior on color {
        ColorAnimation {
            duration: Theme.durFast
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.sp3

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.glyph !== ""
            text: root.glyph
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsIcon
            color: root.primary ? Theme.onAccent : Theme.text
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsBase
            font.weight: root.primary ? Font.Bold : Font.Medium
            color: root.primary ? Theme.onAccent : Theme.textBright
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.hint !== ""
            text: root.hint
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsXs
            color: root.primary ? Theme.alpha(Theme.onAccent, 0.7) : Theme.muted
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.enabled)
            root.clicked()
    }
}
