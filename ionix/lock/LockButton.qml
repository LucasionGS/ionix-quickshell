// A round glyph button for the lock screen.
//
// Not components/IconButton: that one carries a Tooltip, which is a PopupWindow
// parented to the bar's window, and a session-lock surface is no place to hang
// popups off. `label` replaces the glyph with text for the power buttons' "are
// you sure" state.

import QtQuick
import qs.config

Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property color colour: Theme.text
    property color accent: Theme.accentBright
    property int size: 38
    property int fontSize: Theme.fsIconLg
    property bool armed: false

    signal clicked

    implicitWidth: root.label !== "" ? labelText.implicitWidth + Theme.sp6 * 2 : root.size
    implicitHeight: root.size
    radius: root.size / 2
    color: root.armed ? Theme.alpha(root.accent, 0.3) : (mouse.containsMouse ? Theme.alpha(root.accent, 0.18) : "transparent")
    border.width: root.armed ? 1 : 0
    border.color: Theme.alpha(root.accent, 0.7)
    scale: mouse.pressed ? 0.92 : (mouse.containsMouse ? 1.06 : 1)

    Behavior on color {
        ColorAnimation {
            duration: Theme.durNormal
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: Theme.durFast
            easing.type: Theme.easeOvershoot
        }
    }
    Behavior on implicitWidth {
        NumberAnimation {
            duration: Theme.durSlide
            easing.type: Theme.easeStandard
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.label === ""
        text: root.icon
        font.family: Theme.fontFamily
        font.pixelSize: root.fontSize
        color: mouse.containsMouse || root.armed ? Theme.textBright : root.colour
    }

    Text {
        id: labelText
        anchors.centerIn: parent
        visible: root.label !== ""
        text: root.label
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fsMd
        font.weight: Font.DemiBold
        color: Theme.textBright
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
