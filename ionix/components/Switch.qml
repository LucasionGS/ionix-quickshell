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
        color: root.checked ? Theme.alpha(Theme.accentBright, 0.85) : Theme.alpha(Theme.bgDeep, 0.8)
        border.width: 1
        border.color: root.checked ? Theme.accentBright : Theme.border
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
        width: parent.height - 6
        height: width
        radius: width / 2
        y: 3
        x: root.checked ? parent.width - width - 3 : 3
        color: root.checked ? Theme.textBright : Theme.muted
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
