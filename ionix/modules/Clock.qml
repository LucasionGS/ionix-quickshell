// Time over date, in one pill. Click for the calendar.

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

    implicitWidth: pill.implicitWidth
    implicitHeight: Theme.pillHeight

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
        hovered: mouse.containsMouse || root.popoutOpen
        padding: Theme.sp5

        Column {
            spacing: -1

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, Config.clock.format)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsLg
                font.weight: Font.DemiBold
                color: Theme.textBright
            }

            Text {
                visible: Config.clock.showDate
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, Config.clock.dateFormat)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsXs
                color: Theme.muted
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
        onClicked: Popouts.toggle("calendar", root.bar?.screen)
    }

    CalendarPopout {
        anchorItem: root
        shouldOpen: root.popoutOpen
    }
}
