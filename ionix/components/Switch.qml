// An on/off toggle. Used for Wi-Fi, bluetooth adapter power and DND.

import QtQuick
import qs.config

Item {
    id: root

    property bool checked: false
    property bool enabled: true

    signal toggled(bool value)

    implicitWidth: 40
    implicitHeight: 22

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? (Theme.flat ? Theme.accentBright : Theme.alpha(Theme.accentBright, 0.85)) : (Theme.flat ? "transparent" : Theme.alpha(Theme.bgDeep, 0.8))
        border.width: 1
        border.color: root.checked ? Theme.accentBright : (Theme.flat ? Theme.muted : Theme.border)
        opacity: root.enabled ? 1 : 0.4

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
    }

    Rectangle {
        id: knob
        // The flat thumb is smaller while off, and dark on the accent while on.
        readonly property int inset: Theme.flat && !root.checked ? 5 : 4
        width: parent.height - inset * 2
        height: width
        radius: width / 2
        y: inset
        x: root.checked ? parent.width - width - inset : inset
        color: root.checked ? (Theme.flat ? Theme.onAccent : Theme.textBright) : (Theme.flat ? Theme.text : Theme.muted)
        scale: mouse.pressed ? 0.9 : 1.0

        Behavior on x {
            NumberAnimation {
                duration: Theme.durNormal
                easing.type: Theme.easeOvershoot
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: Theme.durNormal
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Theme.durFast
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
