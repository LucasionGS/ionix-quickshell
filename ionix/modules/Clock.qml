// Time over date, in one pill. Click for the calendar.
//
// With a calendar provider signed in, the next meeting joins the pill as a
// second column — title over "in 12m" — while it starts within the configured
// window, and an ongoing one shows as "now". Horizontal bars only: a vertical
// bar has no long axis to put a title on.

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.popouts
import qs.services

Item {
    id: root

    property var bar: null
    readonly property bool popoutOpen: Popouts.isOpen("calendar", root.bar?.screen)

    readonly property bool vertical: Config.barVertical

    readonly property var nextEvent: (!root.vertical && Config.calendar.showNext !== false && Calendar.ready) ? Calendar.nextEvent : null
    readonly property bool nextLive: root.nextEvent !== null && root.nextEvent.startMs <= Calendar.nowMs

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight

    // Ticking once a minute rather than once a second: the bar shows HH:mm, so a
    // 1Hz timer would be 59 wakeups an hour for nothing. The calendar popout runs
    // its own seconds clock while it's open.
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Pill {
        id: pill
        anchors.fill: parent
        accented: true
        interactive: true
        vertical: root.vertical
        hovered: mouse.containsMouse || root.popoutOpen
        // A vertical bar has no room to spare on its short axis, and this padding
        // is the pill's inset on both — sp5 either side would eat 32 of 46px.
        padding: root.vertical ? Theme.sp2 : Theme.sp5

        // Already a column in both orientations; only the formats change, because
        // "HH:mm" at the bar font is wider than a 46px vertical bar.
        Column {
            spacing: -1

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 0.95
                text: Qt.formatDateTime(clock.date, root.vertical ? Config.clock.verticalFormat : Config.clock.format)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsLg
                font.weight: Font.DemiBold
                color: Theme.textBright
            }

            Text {
                visible: Config.clock.showDate
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 0.95
                text: Qt.formatDateTime(clock.date, root.vertical ? Config.clock.verticalDateFormat : Config.clock.dateFormat)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsXs
                color: Theme.muted
            }
        }

        // The Pill's Grid skips invisible children, so this costs no width until
        // there is a meeting to show. Sized in a Column of its own so the title
        // can elide to a fixed maximum rather than stretch the bar.
        Rectangle {
            visible: root.nextEvent !== null
            width: 1
            height: Theme.pillHeight - Theme.sp4
            color: Theme.divider
        }

        Item {
            visible: root.nextEvent !== null
            width: visible ? nextCol.implicitWidth + Theme.sp3 : 0
            height: nextCol.implicitHeight

            Column {
                id: nextCol
                anchors.centerIn: parent
                spacing: -1

                Row {
                    spacing: Theme.sp2

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.nextEvent?.online ? Icons.video : Icons.calendarClock
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsSm
                        color: root.nextLive ? Theme.green : Theme.accentLight
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, Config.calendar.nextMaxWidth ?? 140)
                        elide: Text.ElideRight
                        lineHeight: 0.95
                        text: root.nextEvent?.title ?? ""
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsMd
                        font.weight: Font.DemiBold
                        color: Theme.textBright
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    lineHeight: 0.95
                    text: root.nextEvent ? (root.nextLive ? `now · until ${Calendar.timeOf(root.nextEvent.endMs)}` : `${Calendar.relative(root.nextEvent.startMs)} · ${Calendar.timeOf(root.nextEvent.startMs)}`) : ""
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsXs
                    color: root.nextLive ? Theme.green : Theme.muted
                }
            }
        }
    }

    // Accent underline that grows out from the centre on hover.
    Rectangle {
        anchors.bottom: pill.bottom
        anchors.bottomMargin: 3
        anchors.horizontalCenter: parent.horizontalCenter
        height: 2
        radius: 1
        width: mouse.containsMouse || root.popoutOpen ? pill.width * 0.5 : 0
        color: Theme.accentBright

        Behavior on width {
            NumberAnimation {
                duration: Theme.durSlide
                easing.type: Theme.easeStandard
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        // Middle click goes straight into the meeting the pill is showing.
        onClicked: event => {
            if (event.button === Qt.MiddleButton && root.nextEvent?.joinUrl)
                Calendar.join(root.nextEvent);
            else
                Popouts.toggle("calendar", root.bar?.screen);
        }
    }

    CalendarPopout {
        anchorItem: root
        shouldOpen: root.popoutOpen
    }
}
