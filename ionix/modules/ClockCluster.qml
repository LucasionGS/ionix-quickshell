// Time over date with the notification bell beside it, as one flat button. Opens
// NotificationCentre; right-click is the countdown timer. It stands in for Clock and
// NotificationBell in a theme's module list.

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.popouts
import qs.services

Item {
    id: root

    property var bar: null

    readonly property var screen: root.bar?.screen
    readonly property bool centreOpen: Popouts.isOpen("notifications", root.screen)

    readonly property bool vertical: Config.barVertical

    implicitWidth: root.vertical ? button.thickness : row.implicitWidth + Theme.sp4 * 2
    implicitHeight: root.vertical ? row.implicitHeight + Theme.sp4 * 2 : button.thickness

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    BarTile {
        id: button
        anchors.fill: parent
        active: root.centreOpen || Popouts.isOpen("calendar", root.screen)

        onClicked: {
            if (Countdown.ringing)
                Countdown.dismiss();
            else
                Popouts.toggle("notifications", root.screen);
        }
        onRightClicked: {
            if (Countdown.ringing)
                Countdown.dismiss();
            else
                Popouts.toggle("timer", root.screen);
        }
        onMiddleClicked: Notifications.toggleDnd()

        Grid {
            id: row
            anchors.centerIn: parent
            rows: root.vertical ? 3 : 1
            columns: root.vertical ? 1 : 3
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter
            spacing: root.vertical ? Theme.sp2 : Theme.sp3

            Text {
                visible: Countdown.active
                text: Countdown.format(Countdown.remaining)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsSm
                color: Countdown.ringing ? Theme.red : Theme.textBright
            }

            Column {
                Text {
                    anchors.right: parent.right
                    horizontalAlignment: root.vertical ? Text.AlignHCenter : Text.AlignRight
                    text: Qt.formatDateTime(clock.date, root.vertical ? Config.clock.verticalFormat : Config.clock.format)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsSm
                    color: Theme.textBright
                }

                Text {
                    anchors.right: parent.right
                    visible: Config.clock.showDate
                    text: Qt.formatDateTime(clock.date, root.vertical ? Config.clock.verticalDateFormat : Config.clock.dateFormat)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsSm
                    color: Theme.textBright
                }
            }

            // The bell, with the unread count on it.
            Item {
                width: 20
                height: 20

                Text {
                    anchors.centerIn: parent
                    text: Notifications.dnd ? Icons.bellDnd : Icons.bell
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsIcon
                    color: Theme.textBright
                }

                Rectangle {
                    visible: Notifications.count > 0 && !Notifications.dnd
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.rightMargin: -3
                    anchors.topMargin: -2
                    width: Math.max(14, badge.implicitWidth + 6)
                    height: 14
                    radius: 7
                    color: Theme.accentBright

                    Text {
                        id: badge
                        anchors.centerIn: parent
                        text: Notifications.count > 9 ? "9+" : Notifications.count
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        color: Theme.onAccent
                    }
                }
            }
        }
    }

    NotificationCentre {
        anchorItem: root
        shouldOpen: root.centreOpen
    }

    CalendarPopout {
        anchorItem: root
        screenAlign: "right"
        shouldOpen: Popouts.isOpen("calendar", root.screen)
    }

    TimerPopout {
        anchorItem: root
        screenAlign: "right"
        shouldOpen: Popouts.isOpen("timer", root.screen)
    }
}
