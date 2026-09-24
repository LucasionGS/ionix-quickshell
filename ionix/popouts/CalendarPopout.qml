// Clock and month calendar, with the day's agenda and an event editor.
//
// The grid is the same whether the calendar is on or off; what the calendar
// adds is dots under the days that have events, an agenda for the selected day
// below the grid, a "+" to add an event there, and click-to-edit on the ones
// the daemon marks editable (the local calendar's). A remote provider such as
// Outlook adds its sign-in row and its meetings to the same list. Everything
// here goes through services/Calendar.qml, which reads the daemon's files and
// forwards writes; nothing here knows which provider stored what.
//
// The editor replaces the agenda in place rather than opening a second window:
// it is five fields, and a popout already has keyboard focus. While it is open
// for a new event, clicking a day in the grid moves the event to that day.
//
// Each month can have its own picture behind the panel, dropped into
// calendar.backgrounds.dir as <month>.png/jpg; the one shown follows the month
// being viewed, not today's.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services

Popout {
    id: root

    panelWidth: 340
    backdrop: root.monthBackdrops[root.viewDate.getMonth()] ?? ""
    backdropDim: Math.max(0, Math.min(1, Config.calendar.backgrounds?.dim ?? 0.55))

    // Offset from the current month, moved by the nav buttons and scroll wheel.
    property int monthOffset: 0

    // The day whose agenda is shown. Reset to today on open, like the month.
    property date selectedDate: new Date()

    // A seconds-precision clock, but only while the panel is open — the bar's own
    // clock stays on minutes so the shell idles at zero wakeups.
    SystemClock {
        id: clock
        precision: SystemClock.Seconds
        enabled: root.shouldOpen
    }

    onShouldOpenChanged: {
        root.editorOpen = false;
        if (!root.shouldOpen)
            return;
        root.monthOffset = 0;
        root.selectedDate = new Date(clock.date);
        root.probeBackdrops();
        if (Calendar.remoteReady)
            Calendar.sync();
    }

    // A keybind or `ipc call calendar newEvent` asked for the editor. Only the
    // panel that is actually open reacts, so two monitors don't both edit.
    Connections {
        target: Calendar

        function onEditRequestChanged() {
            if (!root.shouldOpen)
                return;
            root.selectedDate = new Date(Calendar.editRequestDate);
            root.monthOffset = (root.selectedDate.getFullYear() - clock.date.getFullYear()) * 12 + root.selectedDate.getMonth() - clock.date.getMonth();
            root.newEvent();
        }
    }

    // The date part of the seconds clock, as a string so it only notifies once a
    // day: buildMonth() and the agenda label depend on it, and re-running them
    // every second while the panel is open would rebuild 42 delegates a second.
    readonly property string todayKey: Qt.formatDateTime(clock.date, "yyyy-MM-dd")

    readonly property date viewDate: {
        const d = new Date(clock.date);
        d.setDate(1);
        d.setMonth(d.getMonth() + root.monthOffset);
        return d;
    }

    readonly property var dayEvents: Calendar.ready ? Calendar.eventsOn(root.selectedDate) : []

    // "Today", "Tomorrow", "Yesterday", else the weekday and date.
    function labelFor(date) {
        const ymd = root.todayKey.split("-").map(Number);
        const today = new Date(ymd[0], ymd[1] - 1, ymd[2]);
        const sel = new Date(date.getFullYear(), date.getMonth(), date.getDate());
        const diff = Math.round((sel.getTime() - today.getTime()) / 86400000);
        if (diff === 0)
            return "Today";
        if (diff === 1)
            return "Tomorrow";
        if (diff === -1)
            return "Yesterday";
        return Qt.formatDateTime(sel, "dddd d MMMM");
    }

    readonly property string selectedLabel: root.labelFor(root.selectedDate)

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
                        id: cell
                        required property var modelData

                        readonly property bool selected: Calendar.ready && cell.modelData.selected
                        // Up to three dots, one per event, in the calendar's colour.
                        readonly property var marks: Calendar.ready ? cell.modelData.events.slice(0, 3) : []

                        width: grid.width / 7
                        height: 34

                        Rectangle {
                            anchors.centerIn: parent
                            width: 28
                            height: 28
                            radius: 14
                            color: cell.modelData.today ? Theme.accentBright : "transparent"
                            border.width: cell.selected && !cell.modelData.today ? 1 : (dayMouse.containsMouse && !cell.modelData.today ? 1 : 0)
                            border.color: cell.selected ? Theme.alpha(Theme.accentBright, 0.8) : Theme.alpha(Theme.accentBright, 0.4)

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.durNormal
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            // Nudged up a little when there are dots so the pair
                            // still reads as centred in the 28px circle.
                            anchors.verticalCenterOffset: cell.marks.length > 0 ? -2 : 0
                            text: cell.modelData.day
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsMd
                            font.weight: cell.modelData.today ? Font.Bold : Font.Normal
                            color: {
                                if (cell.modelData.today)
                                    return Theme.bgDeep;
                                if (!cell.modelData.inMonth)
                                    return Theme.alpha(Theme.border, 0.6);
                                return cell.modelData.weekend ? Theme.muted : Theme.text;
                            }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 5
                            spacing: 2
                            visible: cell.marks.length > 0

                            Repeater {
                                model: cell.marks

                                delegate: Rectangle {
                                    required property var modelData
                                    width: 4
                                    height: 4
                                    radius: 2
                                    color: {
                                        if (cell.modelData.today)
                                            return Theme.bgDeep;
                                        const c = modelData.color;
                                        if (c && c !== "")
                                            return c;
                                        return cell.modelData.inMonth ? Theme.accentLight : Theme.border;
                                    }
                                    opacity: modelData.cancelled ? 0.4 : 1
                                }
                            }
                        }

                        MouseArea {
                            id: dayMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Calendar.ready ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (!Calendar.ready)
                                    return;
                                root.selectedDate = cell.modelData.date;
                                // A new event follows the day you click.
                                if (root.editorOpen && root.editing === null)
                                    root.editDate = cell.modelData.date;
                                // Picking a grey neighbour-month day turns the page.
                                if (!cell.modelData.inMonth)
                                    root.monthOffset += cell.modelData.date < root.viewDate ? -1 : 1;
                            }
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

        // ── Footer: back to today ───────────────────────────────────────────
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
                    onClicked: {
                        root.monthOffset = 0;
                        root.selectedDate = new Date(clock.date);
                    }
                }
            }
        }

        // ── Calendar ────────────────────────────────────────────────────────
        // Only present with the calendar on; a plain clock ends above.

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.divider
            visible: Calendar.enabled
        }

        ListRow {
            width: parent.width
            visible: Calendar.phase === "starting"
            busy: true
            title: "Starting calendar…"
            subtitle: Calendar.hasRemote ? Calendar.providerLabel : "Local calendar"
        }

        ListRow {
            width: parent.width
            visible: Calendar.phase === "failed"
            icon: Icons.warning
            iconColour: Theme.orange
            title: "The calendar daemon keeps exiting"
            subtitle: "Is ionix-calendar installed? See the shell log"
        }

        // ── Editor ──────────────────────────────────────────────────────────
        Column {
            width: parent.width
            spacing: Theme.sp3
            visible: Calendar.ready && root.editorOpen

            SectionHeader {
                width: parent.width
                text: (root.editing === null ? "New event · " : "Edit · ") + root.labelFor(root.editDate)
                glyph: root.editing === null ? Icons.calendarBlank : Icons.calendarCheck

                Text {
                    visible: root.editing === null
                    text: "click a day to move"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsXs
                    color: Theme.muted
                }
            }

            InputField {
                id: titleField
                width: parent.width
                placeholder: "Title"
                valid: !root.saveAttempted || titleField.text.trim() !== ""
                onAccepted: root.save()
            }

            Item {
                width: parent.width
                height: 30

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.sp2

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "All day"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsSm
                        color: Theme.text
                    }

                    Switch {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: root.allDay
                        onToggled: v => root.allDay = v
                    }
                }

                // Timed: start – end. All-day: a length in days.
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.sp2
                    visible: !root.allDay

                    InputField {
                        id: startField
                        width: 62
                        placeholder: "09:00"
                        horizontalAlignment: TextInput.AlignHCenter
                        valid: root.parseTime(startField.text) >= 0
                        onAccepted: root.save()
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "–"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsMd
                        color: Theme.muted
                    }

                    InputField {
                        id: endField
                        width: 62
                        placeholder: "10:00"
                        horizontalAlignment: TextInput.AlignHCenter
                        valid: root.parseTime(endField.text) >= 0
                        onAccepted: root.save()
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.sp2
                    visible: root.allDay

                    InputField {
                        id: daysField
                        width: 48
                        placeholder: "1"
                        horizontalAlignment: TextInput.AlignHCenter
                        valid: root.parseDays(daysField.text) > 0
                        onAccepted: root.save()
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.parseDays(daysField.text) === 1 ? "day" : "days"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsSm
                        color: Theme.muted
                    }
                }
            }

            InputField {
                id: locationField
                width: parent.width
                placeholder: "Location"
                onAccepted: root.save()
            }

            InputField {
                id: urlField
                width: parent.width
                placeholder: "Meeting link (gives the event a Join button)"
                onAccepted: root.save()
            }

            Item {
                width: parent.width
                height: 26

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Repeat"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsSm
                    color: Theme.text
                }

                Segmented {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    options: root.repeatChoices
                    value: root.repeat
                    onPicked: v => root.repeat = v
                }
            }

            Text {
                width: parent.width
                visible: root.editing !== null && !!root.editing.repeat
                wrapMode: Text.WordWrap
                text: "This event repeats: changes apply to every occurrence."
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsXs
                color: Theme.muted
            }

            Item {
                width: parent.width
                height: 28

                IconButton {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.editing !== null
                    horizontalPadding: Theme.sp2
                    icon: Icons.close
                    label: root.editing !== null && root.editing.repeat ? "Delete series" : "Delete"
                    fontSize: Theme.fsSm
                    colour: Theme.muted
                    hoverColour: Theme.red
                    onClicked: root.removeEvent()
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.sp3

                    IconButton {
                        horizontalPadding: Theme.sp2
                        label: "Cancel"
                        fontSize: Theme.fsSm
                        colour: Theme.muted
                        onClicked: root.editorOpen = false
                    }

                    IconButton {
                        horizontalPadding: Theme.sp3
                        icon: Icons.check
                        label: "Save"
                        fontSize: Theme.fsSm
                        colour: root.canSave ? Theme.accentLight : Theme.border
                        hoverColour: root.canSave ? Theme.accentBright : Theme.border
                        onClicked: root.save()
                    }
                }
            }
        }

        // ── Agenda for the selected day ─────────────────────────────────────
        Column {
            width: parent.width
            spacing: Theme.sp2
            visible: Calendar.ready && !root.editorOpen

            SectionHeader {
                width: parent.width
                text: root.selectedLabel
                glyph: Icons.calendarClock

                Row {
                    spacing: Theme.sp2

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.dayEvents.length > 0 ? `${root.dayEvents.length}` : ""
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsXs
                        color: Theme.muted
                    }

                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Calendar.writable
                        icon: Icons.plus
                        fontSize: Theme.fsMd
                        colour: Theme.muted
                        hoverColour: Theme.accentLight
                        horizontalPadding: Theme.sp2
                        tooltip: "New event on this day"
                        onClicked: root.newEvent()
                    }
                }
            }

            Text {
                width: parent.width
                visible: root.dayEvents.length === 0
                leftPadding: Theme.sp3
                text: "Nothing scheduled"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsSm
                color: Theme.muted
            }

            // Scrolls past a few rows rather than growing the panel down the
            // screen — a busy day can be a dozen entries.
            Flickable {
                id: agendaFlick
                width: parent.width
                height: Math.min(agenda.height, 240)
                contentHeight: agenda.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: agenda
                    width: agendaFlick.width
                    spacing: 1

                    Repeater {
                        model: root.dayEvents

                        delegate: ListRow {
                            id: eventRow
                            required property var modelData

                            readonly property bool over: !eventRow.modelData.allDay && eventRow.modelData.endMs <= Calendar.nowMs
                            readonly property bool live: !eventRow.modelData.allDay && eventRow.modelData.startMs <= Calendar.nowMs && eventRow.modelData.endMs > Calendar.nowMs

                            width: parent.width
                            icon: eventRow.modelData.online ? Icons.video : (eventRow.modelData.allDay ? Icons.calendarBlank : Icons.calendarClock)
                            iconColour: {
                                if (eventRow.modelData.cancelled)
                                    return Theme.red;
                                if (eventRow.live)
                                    return Theme.green;
                                const c = eventRow.modelData.color;
                                return (c && c !== "") ? c : Theme.accentLight;
                            }
                            selected: eventRow.live
                            opacity: eventRow.over || eventRow.modelData.cancelled ? 0.55 : 1
                            title: (eventRow.modelData.cancelled ? "Cancelled: " : "") + eventRow.modelData.title
                            subtitle: {
                                const parts = [Calendar.span(eventRow.modelData)];
                                if (eventRow.live)
                                    parts.push("now");
                                if (eventRow.modelData.location && eventRow.modelData.location !== "")
                                    parts.push(eventRow.modelData.location);
                                if (eventRow.modelData.repeat)
                                    parts.push(eventRow.modelData.repeat.freq);
                                // Name the calendar only when there is more than
                                // one to tell apart.
                                if (Calendar.hasRemote && eventRow.modelData.source !== "local")
                                    parts.push(eventRow.modelData.calendarName);
                                return parts.join(" · ");
                            }
                            onClicked: {
                                if (eventRow.modelData.editable)
                                    root.editEvent(eventRow.modelData);
                                else
                                    Calendar.openUrl(eventRow.modelData.webLink);
                            }

                            IconButton {
                                visible: eventRow.modelData.joinUrl !== ""
                                horizontalPadding: Theme.sp2
                                icon: eventRow.modelData.source === "outlook" ? Icons.teams : Icons.video
                                label: "Join"
                                fontSize: Theme.fsSm
                                colour: eventRow.live ? Theme.green : Theme.accentLight
                                tooltip: "Open the meeting link"
                                onClicked: Calendar.join(eventRow.modelData)
                            }
                        }
                    }
                }
            }
        }

        // ── Remote account ──────────────────────────────────────────────────
        // Everything up to the first successful sign-in. Hidden once signed in;
        // the footer carries the account from then on.
        Column {
            width: parent.width
            spacing: Theme.sp2
            visible: Calendar.ready && Calendar.hasRemote && !Calendar.remoteReady && !root.editorOpen

            ListRow {
                width: parent.width
                visible: Calendar.phase === "unconfigured"
                icon: Icons.warning
                iconColour: Theme.orange
                title: `${Calendar.providerLabel} is not set up`
                subtitle: Calendar.error !== "" ? Calendar.error : "Check the calendar section of config.json"
            }

            ListRow {
                width: parent.width
                visible: Calendar.phase === "signedout"
                icon: Icons.signIn
                title: `Sign in to ${Calendar.providerLabel}`
                subtitle: Calendar.error !== "" ? Calendar.error : "Adds your meetings here, with Join buttons and reminders"
                onClicked: Calendar.login()
            }

            // Device code: show it big, offer the URL, and wait.
            Column {
                width: parent.width
                spacing: Theme.sp3
                visible: Calendar.phase === "signin"

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: `Open the link below and enter this code. Signing you in as soon as ${Calendar.providerLabel} confirms it.`
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsSm
                    color: Theme.muted
                }

                Rectangle {
                    width: parent.width
                    height: 44
                    radius: Theme.rSm
                    color: Theme.alpha(Theme.bgDeep, 0.7)
                    border.width: 1
                    border.color: codeMouse.containsMouse ? Theme.accentBright : Theme.border

                    Behavior on border.color {
                        ColorAnimation {
                            duration: Theme.durNormal
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: Calendar.signin?.userCode ?? ""
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fsTitle
                        font.weight: Font.DemiBold
                        font.letterSpacing: 3
                        color: Theme.textBright
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.sp3
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.copied ? Icons.check : Icons.copy
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsMd
                        color: root.copied ? Theme.green : Theme.muted
                    }

                    MouseArea {
                        id: codeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.copyCode()
                    }
                }

                Row {
                    spacing: Theme.sp3

                    IconButton {
                        horizontalPadding: Theme.sp2
                        icon: Icons.openExternal
                        label: (Calendar.signin?.verificationUri ?? "").replace(/^https?:\/\//, "")
                        fontSize: Theme.fsMd
                        colour: Theme.accentLight
                        onClicked: Calendar.openUrl(Calendar.signin?.verificationUri ?? "")
                    }

                    IconButton {
                        horizontalPadding: Theme.sp2
                        icon: Icons.close
                        label: "Cancel"
                        fontSize: Theme.fsMd
                        colour: Theme.muted
                        onClicked: Calendar.cancelLogin()
                    }
                }
            }
        }

        // ── Status line ─────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: 22
            visible: Calendar.ready && !root.editorOpen

            // A write that failed is worth showing whatever the remote is
            // doing; a remote sync error only while a remote is signed in.
            readonly property bool showError: Calendar.error !== "" && (Calendar.remoteReady || Calendar.error.startsWith("Calendar: "))

            Text {
                anchors.left: parent.left
                anchors.right: statusButtons.left
                anchors.rightMargin: Theme.sp2
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: {
                    if (parent.showError)
                        return Calendar.error;
                    if (!Calendar.remoteReady)
                        return `Local calendar · ${Calendar.events.length} events`;
                    if (Calendar.phase === "syncing")
                        return `Syncing ${Calendar.accountLabel}…`;
                    const age = Calendar.syncAgeMinutes;
                    const when = age < 0 ? "Not synced yet" : (age === 0 ? "Synced just now" : `Synced ${age}m ago`);
                    return Calendar.accountLabel !== "" ? `${when} · ${Calendar.accountLabel}` : when;
                }
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsXs
                color: parent.showError ? Theme.orange : Theme.muted
            }

            Row {
                id: statusButtons
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                IconButton {
                    visible: Calendar.remoteReady
                    icon: Icons.refresh
                    fontSize: Theme.fsMd
                    colour: Theme.muted
                    hoverColour: Theme.accentLight
                    horizontalPadding: Theme.sp2
                    tooltip: "Sync now"
                    onClicked: {
                        Calendar.lastSyncRequest = 0;
                        Calendar.sync();
                    }
                }

                IconButton {
                    visible: Calendar.remoteReady
                    icon: Icons.logout
                    fontSize: Theme.fsMd
                    colour: Theme.muted
                    hoverColour: Theme.red
                    horizontalPadding: Theme.sp2
                    tooltip: `Sign out of ${Calendar.providerLabel}`
                    onClicked: Calendar.logout()
                }
            }
        }
    }

    // ── Editor state ────────────────────────────────────────────────────────

    property bool editorOpen: false
    // The event being edited (a feed entry), or null for a new one.
    property var editing: null
    // The day the event lands on. For a repeating series this is the series'
    // first day, not the occurrence that was clicked.
    property date editDate: new Date()
    property bool allDay: false
    property string repeat: "none"
    property bool saveAttempted: false

    readonly property var repeatChoices: [
        {
            value: "none",
            label: "Once"
        },
        {
            value: "daily",
            label: "Day"
        },
        {
            value: "weekly",
            label: "Week"
        },
        {
            value: "monthly",
            label: "Month"
        },
        {
            value: "yearly",
            label: "Year"
        }
    ]

    readonly property bool canSave: titleField.text.trim() !== "" && (root.allDay ? root.parseDays(daysField.text) > 0 : (root.parseTime(startField.text) >= 0 && root.parseTime(endField.text) >= 0))

    // "9", "9:30", "0930", "9.30" → minutes since midnight, or -1.
    function parseTime(text) {
        let raw = String(text ?? "").trim().replace(".", ":");
        if (raw === "")
            return -1;
        if (raw.indexOf(":") === -1) {
            if (raw.length <= 2)
                raw += ":00";
            else
                raw = raw.padStart(4, "0").slice(0, 2) + ":" + raw.padStart(4, "0").slice(2);
        }
        const parts = raw.split(":");
        const h = parseInt(parts[0], 10);
        const m = parseInt(parts[1], 10);
        if (isNaN(h) || isNaN(m) || h < 0 || h > 23 || m < 0 || m > 59)
            return -1;
        return h * 60 + m;
    }

    function parseDays(text) {
        const n = parseInt(String(text ?? "").trim(), 10);
        return isNaN(n) ? 0 : n;
    }

    function pad(n) {
        return String(n).padStart(2, "0");
    }

    function newEvent() {
        root.editing = null;
        root.editDate = new Date(root.selectedDate);
        root.saveAttempted = false;
        root.allDay = false;
        root.repeat = "none";
        titleField.text = "";
        locationField.text = "";
        urlField.text = "";
        daysField.text = "1";
        // The next full hour when adding to today, nine o'clock otherwise.
        const now = new Date(clock.date);
        const sameDay = Qt.formatDate(root.selectedDate, "yyyy-MM-dd") === root.todayKey;
        const startH = sameDay ? Math.min(23, now.getHours() + 1) : 9;
        startField.text = `${root.pad(startH)}:00`;
        endField.text = startH >= 23 ? "23:59" : `${root.pad(startH + 1)}:00`;
        root.editorOpen = true;
        titleField.input.forceActiveFocus();
    }

    function editEvent(e) {
        root.editing = e;
        const start = new Date(e.startMs);
        const end = new Date(e.endMs);
        if (e.repeat && e.seriesDate) {
            const ymd = String(e.seriesDate).split("-").map(Number);
            root.editDate = new Date(ymd[0], ymd[1] - 1, ymd[2]);
        } else {
            root.editDate = new Date(start.getFullYear(), start.getMonth(), start.getDate());
        }
        root.saveAttempted = false;
        root.allDay = e.allDay === true;
        root.repeat = e.repeat?.freq ?? "none";
        titleField.text = e.title ?? "";
        locationField.text = e.location ?? "";
        urlField.text = e.joinUrl ?? "";
        daysField.text = String(Math.max(1, Math.round((e.endMs - e.startMs) / 86400000)));
        startField.text = `${root.pad(start.getHours())}:${root.pad(start.getMinutes())}`;
        endField.text = `${root.pad(end.getHours())}:${root.pad(end.getMinutes())}`;
        root.editorOpen = true;
        titleField.input.forceActiveFocus();
    }

    function save() {
        root.saveAttempted = true;
        if (!root.canSave)
            return;
        const payload = {
            title: titleField.text.trim(),
            allDay: root.allDay,
            date: Qt.formatDate(root.editDate, "yyyy-MM-dd"),
            location: locationField.text.trim(),
            url: urlField.text.trim(),
            repeat: root.repeat === "none" ? null : {
                freq: root.repeat,
                interval: 1
            }
        };
        if (root.allDay) {
            payload.days = root.parseDays(daysField.text);
        } else {
            const s = root.parseTime(startField.text);
            const t = root.parseTime(endField.text);
            payload.startTime = `${root.pad(Math.floor(s / 60))}:${root.pad(s % 60)}`;
            payload.endTime = `${root.pad(Math.floor(t / 60))}:${root.pad(t % 60)}`;
        }
        if (root.editing !== null) {
            payload.id = root.editing.seriesId;
            Calendar.update(payload);
        } else {
            Calendar.create(payload);
        }
        // Show the day the event went to, so the new row is visible at once.
        root.selectedDate = new Date(root.editDate);
        root.editorOpen = false;
    }

    function removeEvent() {
        if (root.editing === null)
            return;
        Calendar.remove(root.editing.seriesId);
        root.editorOpen = false;
    }

    // ── Helpers ─────────────────────────────────────────────────────────────

    property bool copied: false

    Timer {
        id: copiedReset
        interval: 1500
        onTriggered: root.copied = false
    }

    function copyCode() {
        const code = Calendar.signin?.userCode ?? "";
        if (code === "")
            return;
        Quickshell.execDetached(["sh", "-c", "command -v wl-copy >/dev/null 2>&1 && printf %s \"$1\" | wl-copy", "_", code]);
        root.copied = true;
        copiedReset.restart();
    }

    // ── Month backgrounds ───────────────────────────────────────────────────
    //
    // The folder is listed once per open rather than watched, so dropping a
    // picture in shows up the next time the panel opens. Listed rather than
    // handed to an Image per month, because Image logs a warning for every
    // source it cannot open and most months will have no picture at all.

    readonly property string backdropDir: {
        const home = Quickshell.env("HOME");
        const configured = (Config.calendar.backgrounds?.dir ?? "").trim().replace(/^~(?=\/|$)/, home);
        return configured !== "" ? configured : `${Config.userDir}/calendar`;
    }

    // Month index → file:// URL, for the months that have one.
    property var monthBackdrops: ({})

    function probeBackdrops() {
        backdropProbe.running = false;
        backdropProbe.running = true;
    }

    onBackdropDirChanged: root.probeBackdrops()

    // English names on purpose: these are filenames, and they should not change
    // meaning when the locale does.
    readonly property var monthNames: ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"]

    function parseBackdrops(listing) {
        const found = {};
        for (const path of listing.split("\n")) {
            const m = path.match(/([^/]+)\.(png|jpe?g|webp)$/i);
            if (!m)
                continue;
            const name = m[1].toLowerCase();
            const month = root.monthNames.findIndex(n => n === name || n.slice(0, 3) === name);
            // The glob is sorted, so of "jan.png" and "january.jpg" the first wins.
            if (month >= 0 && found[month] === undefined)
                found[month] = "file://" + path.split("/").map(encodeURIComponent).join("/");
        }
        return found;
    }

    Process {
        id: backdropProbe
        command: ["sh", "-c", 'for f in "$1"/*; do [ -f "$f" ] && [ -r "$f" ] && printf "%s\n" "$f"; done', "sh", root.backdropDir]
        stdout: StdioCollector {
            onStreamFinished: root.monthBackdrops = root.parseBackdrops(this.text)
        }
    }

    // Six weeks of cells, Monday-first, with the neighbouring months greyed rather
    // than blank so the grid never has holes. Each cell carries its events so the
    // delegate draws dots without a lookup of its own.
    function buildMonth() {
        const view = root.viewDate;
        const year = view.getFullYear();
        const month = view.getMonth();
        const todayKey = root.todayKey;
        const sel = root.selectedDate;
        const ready = Calendar.ready;

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
                date: d,
                inMonth: d.getMonth() === month,
                weekend: weekday >= 5,
                today: Qt.formatDateTime(d, "yyyy-MM-dd") === todayKey,
                selected: d.getFullYear() === sel.getFullYear() && d.getMonth() === sel.getMonth() && d.getDate() === sel.getDate(),
                events: ready ? Calendar.eventsOn(d) : []
            });
        }
        return cells;
    }
}
