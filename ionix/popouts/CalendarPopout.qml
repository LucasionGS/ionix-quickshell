// Clock and month calendar.

import QtQuick
import Quickshell
import qs.config
import qs.components

Popout {
    id: root

    panelWidth: 340

    // Offset from the current month, moved by the nav buttons and scroll wheel.
    property int monthOffset: 0

    // A seconds-precision clock, but only while the panel is open — the bar's own
    // clock stays on minutes so the shell idles at zero wakeups.
    SystemClock {
        id: clock
        precision: SystemClock.Seconds
        enabled: root.shouldOpen
    }

    onShouldOpenChanged: if (shouldOpen)
        root.monthOffset = 0

    readonly property date viewDate: {
        const d = new Date(clock.date);
        d.setDate(1);
        d.setMonth(d.getMonth() + root.monthOffset);
        return d;
    }

    Column {
        width: parent.width
        spacing: Theme.sp4

        // ── Header ──────────────────────────────────────────────────────────
        Column {
            width: parent.width
            spacing: 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "HH:mm:ss")
                font.family: Theme.fontFamily
                font.pixelSize: 32
                font.weight: Font.Light
                color: Theme.textBright
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsMd
                color: Theme.accentLight
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.divider
        }

        // ── Month nav ───────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: 28

            IconButton {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                icon: Icons.chevronLeft
                colour: Theme.muted
                hoverColour: Theme.accentLight
                horizontalPadding: Theme.sp3
                onClicked: root.monthOffset--
            }

            Text {
                anchors.centerIn: parent
                text: Qt.formatDateTime(root.viewDate, "MMMM yyyy")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsBase
                font.weight: Font.DemiBold
                color: Theme.textBright
            }

            IconButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                icon: Icons.chevronRight
                colour: Theme.muted
                hoverColour: Theme.accentLight
                horizontalPadding: Theme.sp3
                onClicked: root.monthOffset++
            }
        }

        // ── Grid ────────────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: weekdayRow.height + grid.height + Theme.sp2

            Row {
                id: weekdayRow
                width: parent.width

                Repeater {
                    model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

                    delegate: Text {
                        required property string modelData
                        required property int index
                        width: parent.width / 7
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsXs
                        font.weight: Font.Bold
                        color: index >= 5 ? Theme.muted : Theme.accentLight
                    }
                }
            }

            Grid {
                id: grid
                anchors.top: weekdayRow.bottom
                anchors.topMargin: Theme.sp2
                width: parent.width
                columns: 7

                Repeater {
                    model: root.buildMonth()

                    delegate: Item {
                        required property var modelData
                        width: grid.width / 7
                        height: 34

                        Rectangle {
                            anchors.centerIn: parent
                            width: 28
                            height: 28
                            radius: 14
                            color: modelData.today ? Theme.accentBright : "transparent"
                            border.width: dayMouse.containsMouse && !modelData.today ? 1 : 0
                            border.color: Theme.alpha(Theme.accentBright, 0.4)

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.durNormal
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.day
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsMd
                            font.weight: modelData.today ? Font.Bold : Font.Normal
                            color: {
                                if (modelData.today)
                                    return Theme.bgDeep;
                                if (!modelData.inMonth)
                                    return Theme.alpha(Theme.border, 0.6);
                                return modelData.weekend ? Theme.muted : Theme.text;
                            }
                        }

                        MouseArea {
                            id: dayMouse
                            anchors.fill: parent
                            hoverEnabled: true
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: event => {
                    root.monthOffset += event.angleDelta.y > 0 ? -1 : 1;
                    event.accepted = true;
                }
            }
        }

        // ── Footer ──────────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: 24
            visible: root.monthOffset !== 0

            Rectangle {
                anchors.centerIn: parent
                width: todayLabel.implicitWidth + Theme.sp5
                height: 24
                radius: 12
                color: todayMouse.containsMouse ? Theme.alpha(Theme.accentBright, 0.2) : Theme.alpha(Theme.bgCard, 0.5)
                border.width: 1
                border.color: Theme.alpha(Theme.accentBright, 0.3)

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durNormal
                    }
                }

                Text {
                    id: todayLabel
                    anchors.centerIn: parent
                    text: "Today"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsSm
                    color: Theme.text
                }

                MouseArea {
                    id: todayMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.monthOffset = 0
                }
            }
        }
    }

    // Six weeks of cells, Monday-first, with the neighbouring months greyed rather
    // than blank so the grid never has holes.
    function buildMonth() {
        const view = root.viewDate;
        const year = view.getFullYear();
        const month = view.getMonth();
        const now = new Date(clock.date);

        // JS weekday is Sunday=0; shift so Monday=0.
        const firstWeekday = (new Date(year, month, 1).getDay() + 6) % 7;
        const start = new Date(year, month, 1 - firstWeekday);

        const cells = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(start);
            d.setDate(start.getDate() + i);
            const weekday = (d.getDay() + 6) % 7;
            cells.push({
                day: d.getDate(),
                inMonth: d.getMonth() === month,
                weekend: weekday >= 5,
                today: d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth() && d.getDate() === now.getDate()
            });
        }
        return cells;
    }
}
