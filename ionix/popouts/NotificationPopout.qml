// The notification centre: everything the server is still holding.
//
// Height is clamped to a fraction of the screen and the list scrolls inside it —
// a hundred pending notifications should make a scrollbar, not a panel taller than
// the monitor.

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.config
import qs.components
import qs.services

Popout {
    id: root

    panelWidth: 390

    readonly property int maxListHeight: Math.round((root.screen?.height ?? 1080) * 0.55)

    Column {
        width: parent.width
        spacing: Theme.sp3

        // ── Header ──────────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: 24

            Text {
                id: heading
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Notifications"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsLg
                font.weight: Font.DemiBold
                color: Theme.textBright
            }

            Rectangle {
                id: countBadge
                anchors.left: heading.right
                anchors.leftMargin: Theme.sp3
                anchors.verticalCenter: parent.verticalCenter
                visible: Notifications.count > 0
                width: Math.max(20, countLabel.implicitWidth + Theme.sp3)
                height: 18
                radius: 9
                color: Notifications.hasCritical ? Theme.alpha(Theme.red, 0.25) : Theme.alpha(Theme.accentBright, 0.2)
                border.width: 1
                border.color: Notifications.hasCritical ? Theme.alpha(Theme.red, 0.5) : Theme.alpha(Theme.accentBright, 0.4)

                Text {
                    id: countLabel
                    anchors.centerIn: parent
                    text: Notifications.count
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fsXs
                    font.weight: Font.DemiBold
                    color: Notifications.hasCritical ? Theme.red : Theme.accentLight
                }
            }

            Rectangle {
                id: clearButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: Notifications.count > 0
                width: clearLabel.implicitWidth + Theme.sp4
                height: 22
                radius: Theme.rSm
                color: clearMouse.containsMouse ? Theme.alpha(Theme.red, 0.18) : "transparent"
                border.width: 1
                border.color: clearMouse.containsMouse ? Theme.alpha(Theme.red, 0.45) : Theme.alpha(Theme.border, 0.45)

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durFast
                    }
                }

                Text {
                    id: clearLabel
                    anchors.centerIn: parent
                    text: "Clear all"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsXs
                    color: clearMouse.containsMouse ? Theme.red : Theme.muted
                }

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifications.clearAll()
                }
            }
        }

        // ── Do not disturb ──────────────────────────────────────────────────
        Item {
            width: parent.width
            height: 28

            Text {
                id: dndGlyph
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: Notifications.dnd ? Icons.bellDnd : Icons.bell
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsIcon
                color: Notifications.dnd ? Theme.orange : Theme.muted
            }

            Text {
                anchors.left: dndGlyph.right
                anchors.leftMargin: Theme.sp3
                anchors.verticalCenter: parent.verticalCenter
                text: "Do not disturb"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsMd
                color: Notifications.dnd ? Theme.text : Theme.muted
            }

            Switch {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: Notifications.dnd
                onToggled: Notifications.toggleDnd()
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.divider
        }

        // ── Empty state ─────────────────────────────────────────────────────
        Item {
            width: parent.width
            visible: Notifications.count === 0
            height: visible ? 96 : 0

            Column {
                anchors.centerIn: parent
                spacing: Theme.sp2

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Icons.bell
                    font.family: Theme.fontFamily
                    font.pixelSize: 32
                    color: Theme.alpha(Theme.border, 0.8)
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Notifications.dnd ? "Do not disturb is on" : "Nothing to see here"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMd
                    color: Theme.muted
                }
            }
        }

        // ── List ────────────────────────────────────────────────────────────
        Flickable {
            width: parent.width
            visible: Notifications.count > 0
            height: visible ? Math.min(listColumn.implicitHeight, root.maxListHeight) : 0
            contentHeight: listColumn.implicitHeight
            contentWidth: width
            interactive: contentHeight > height
            clip: interactive
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: listColumn
                width: parent.width
                spacing: Theme.sp2

                Repeater {
                    model: Notifications.list

                    delegate: NotificationCard {
                        required property var modelData

                        width: listColumn.width
                        notification: modelData
                        bodyLines: 6
                    }
                }
            }
        }
    }
}
