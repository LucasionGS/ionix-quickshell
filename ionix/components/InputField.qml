// A single-line text field in the popout style: dark fill, accent border on
// focus, placeholder that gets out of the way. Hue's IP entry was the first of
// these inline; the calendar editor needs five, so it became a component.

import QtQuick
import qs.config

Rectangle {
    id: root

    property alias text: input.text
    property alias input: input
    property string placeholder: ""
    // Drawn in the error colour when false — the caller decides what valid is.
    property bool valid: true
    property int horizontalAlignment: TextInput.AlignLeft

    signal accepted

    implicitWidth: 120
    implicitHeight: 30
    radius: Theme.rSm
    color: Theme.alpha(Theme.bgDeep, 0.7)
    border.width: 1
    border.color: !root.valid ? Theme.red : (input.activeFocus ? Theme.accentBright : Theme.border)

    Behavior on border.color {
        ColorAnimation {
            duration: Theme.durNormal
        }
    }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: Theme.sp3
        anchors.rightMargin: Theme.sp3
        verticalAlignment: TextInput.AlignVCenter
        horizontalAlignment: root.horizontalAlignment
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fsMd
        color: Theme.textBright
        selectionColor: Theme.alpha(Theme.accentBright, 0.4)
        selectedTextColor: Theme.textBright
        clip: true
        onAccepted: root.accepted()

        Text {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: root.horizontalAlignment
            // Stays while focused: an empty field with the caret in it and no
            // hint reads as broken, not as ready.
            visible: input.text === ""
            text: root.placeholder
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsMd
            color: Theme.muted
            elide: Text.ElideRight
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onClicked: input.forceActiveFocus()
    }
}
