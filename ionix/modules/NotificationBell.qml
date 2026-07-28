// Notification bell, backed by swaync. Left toggles the centre, right toggles DND.

import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property var bar: null

    implicitWidth: button.implicitWidth
    implicitHeight: Theme.pillHeight

    IconButton {
        id: button
        anchors.fill: parent
        icon: Notifications.dnd ? Icons.bellDnd : Icons.bell
        colour: Notifications.dnd ? Theme.muted : Theme.accentBright
        tooltip: {
            if (Notifications.dnd)
                return "Do not disturb  ·  right-click to turn off";
            if (Notifications.count > 0)
                return `${Notifications.count} notification${Notifications.count === 1 ? "" : "s"}`;
            return "Notifications  ·  right-click for DND";
        }

        onClicked: Notifications.toggle()
        onRightClicked: Notifications.toggleDnd()

        // Unread dot rather than a number: the count is in the tooltip, and a bare
        // dot keeps the bar's right edge from reflowing as notifications arrive.
        Rectangle {
            visible: Notifications.count > 0 && !Notifications.dnd
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 6
            anchors.topMargin: 8
            width: 7
            height: 7
            radius: 3.5
            color: Theme.red
            border.width: 1
            border.color: Theme.bgDeep

            SequentialAnimation on scale {
                running: Notifications.count > 0
                loops: 3
                alwaysRunToEnd: true
                NumberAnimation {
                    to: 1.4
                    duration: 220
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    to: 1.0
                    duration: 220
                    easing.type: Easing.InCubic
                }
            }
        }
    }
}
