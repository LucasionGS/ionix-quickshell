// Notifications in one panel, a month calendar under it, stacked with a gap and
// hugging the right-hand screen edge. Opened by ClockCluster.
//
// The agenda and event editing stay in CalendarPopout, reached from the calendar
// panel's header. This one only answers "what day is it, and is anything on".

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

Popout {
    id: root

    panelWidth: 380
    padding: 0
    bare: true
    screenAlign: "right"

    // The month on show, as its first day.
    property date month: new Date(new Date().getFullYear(), new Date().getMonth(), 1)
    property bool collapsed: false

    readonly property var days: {
        // Monday first; the grid always runs six weeks, so changing month never
        // changes the panel's height.
        const first = root.month;
        const offset = (first.getDay() + 6) % 7;
        const out = [];
        for (let i = 0; i < 42; i++)
            out.push(new Date(first.getFullYear(), first.getMonth(), 1 - offset + i));
        return out;
    }

    onShouldOpenChanged: {
        if (root.shouldOpen) {
            const now = new Date();
            root.month = new Date(now.getFullYear(), now.getMonth(), 1);
        }
    }

    Column {
        width: root.panelWidth
        spacing: root.flyoutGap

        // ── Notifications ───────────────────────────────────────────────────
        GlassPanel {
            width: parent.width
            padding: Theme.sp5

            Column {
                width: parent.width
                spacing: Theme.sp3

                Item {
                    width: parent.width
                    height: 28

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Notifications"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsBase
                        font.weight: Font.DemiBold
                        color: Theme.textBright
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.sp2

                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitHeight: 28
                            icon: Notifications.dnd ? Icons.bellDnd : Icons.bell
                            active: Notifications.dnd
                            colour: Notifications.dnd ? Theme.accentBright : Theme.text
                            hoverColour: Notifications.dnd ? Theme.accentBright : Theme.textBright
                            tooltip: Notifications.dnd ? "Turn off do not disturb" : "Do not disturb"
                            onClicked: Notifications.toggleDnd()
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Notifications.count > 0
                            width: clearLabel.implicitWidth + Theme.sp4 * 2
                            height: 28
                            radius: Theme.rSm
                            color: clearMouse.pressed ? Theme.subtlePressed : (clearMouse.containsMouse ? Theme.subtleHover : Theme.controlFill)
                            border.width: 1
                            border.color: Theme.controlStroke

                            Text {
                                id: clearLabel
                                anchors.centerIn: parent
                                text: "Clear all"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsSm
                                color: Theme.textBright
                            }

                            MouseArea {
                                id: clearMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: Notifications.clearAll()
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: Notifications.count === 0
                    topPadding: Theme.sp6
                    bottomPadding: Theme.sp6
                    horizontalAlignment: Text.AlignHCenter
                    text: Notifications.dnd ? "Do not disturb is on" : "No new notifications"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsSm
                    color: Theme.muted
                }

                Flickable {
                    width: parent.width
                    visible: Notifications.count > 0
                    // Half the screen less what the calendar takes, so the two panels
                    // together always fit above the taskbar.
                    height: visible ? Math.min(list.implicitHeight, Math.max(160, (root.screen?.height ?? 1080) - 620)) : 0
                    contentHeight: list.implicitHeight
                    contentWidth: width
                    interactive: contentHeight > height
                    clip: interactive
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: list
                        width: parent.width
                        spacing: Theme.sp2

                        Repeater {
                            model: Notifications.list

                            delegate: NotificationCard {
                                required property var modelData

                                width: list.width
                                notification: modelData
                                bodyLines: 4
                            }
                        }
                    }
                }
            }
        }

        // ── Calendar ────────────────────────────────────────────────────────
        GlassPanel {
            width: parent.width
            padding: Theme.sp5

            Column {
                width: parent.width
                spacing: Theme.sp3

                // Today, and the arrow that folds the month away.
                Item {
                    width: parent.width
                    height: 28

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDate(new Date(), "dddd, MMMM d")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsBase
                        font.weight: Font.DemiBold
                        color: Theme.textBright
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.sp1

                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Config.calendar.provider !== "none"
                            implicitHeight: 28
                            icon: Icons.calendarCheck
                            colour: Theme.textBright
                            tooltip: "Agenda and events"
                            onClicked: Popouts.open("calendar", Popouts.screen)
                        }

                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitHeight: 28
                            icon: root.collapsed ? Icons.chevronUp : Icons.chevronDown
                            colour: Theme.textBright
                            tooltip: root.collapsed ? "Show the month" : "Hide the month"
                            onClicked: root.collapsed = !root.collapsed
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.divider
                    visible: !root.collapsed
                }

                // Month and its arrows.
                Item {
                    width: parent.width
                    height: 28
                    visible: !root.collapsed

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDate(root.month, "MMMM yyyy")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsBase
                        font.weight: Font.DemiBold
                        color: Theme.textBright
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter

                        IconButton {
                            implicitHeight: 28
                            icon: Icons.chevronUp
                            colour: Theme.textBright
                            onClicked: root.month = new Date(root.month.getFullYear(), root.month.getMonth() - 1, 1)
                        }

                        IconButton {
                            implicitHeight: 28
                            icon: Icons.chevronDown
                            colour: Theme.textBright
                            onClicked: root.month = new Date(root.month.getFullYear(), root.month.getMonth() + 1, 1)
                        }
                    }
                }

                Grid {
                    visible: !root.collapsed
                    columns: 7

                    readonly property int cell: Math.floor(parent.width / 7)

                    Repeater {
                        model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

                        delegate: Text {
                            required property string modelData

                            width: parent.cell
                            height: 32
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: modelData
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsSm
                            font.weight: Font.DemiBold
                            color: Theme.textBright
                        }
                    }

                    Repeater {
                        model: root.days

                        delegate: Item {
                            id: day
                            required property var modelData

                            readonly property bool inMonth: day.modelData.getMonth() === root.month.getMonth()
                            readonly property bool today: day.modelData.toDateString() === new Date().toDateString()
                            readonly property bool busy: Calendar.ready && Calendar.eventsOn(day.modelData).length > 0

                            width: parent.cell
                            height: 40

                            Rectangle {
                                anchors.centerIn: parent
                                width: 36
                                height: 36
                                radius: 18
                                color: day.today ? Theme.accentBright : (dayMouse.containsMouse ? Theme.subtleHover : "transparent")
                            }

                            Text {
                                anchors.centerIn: parent
                                text: day.modelData.getDate()
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsBase
                                color: day.today ? Theme.onAccent : (day.inMonth ? Theme.textBright : Theme.muted)
                            }

                            Rectangle {
                                visible: day.busy
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 6
                                width: 4
                                height: 4
                                radius: 2
                                color: day.today ? Theme.onAccent : Theme.accentBright
                            }

                            MouseArea {
                                id: dayMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    if (Config.calendar.provider !== "none")
                                        Popouts.open("calendar", Popouts.screen);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
