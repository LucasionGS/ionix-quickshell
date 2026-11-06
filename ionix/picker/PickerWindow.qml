// The share picker's dialog: a dimmed overlay on the monitor that was focused
// when the app asked, with one page each for screens, windows and an area.
//
// Modal on its monitor and holding the keyboard, like the Alt+Tab switcher. A
// click outside the panel does nothing: a share dialog that cancels on a stray
// click loses the answer the app is waiting for.
//
// It maps only once the card for its own monitor has a frame. That card is a
// still (`live: false`), taken while the overlay is not yet up, so the preview
// shows the desktop instead of the picker inside the picker. 600 ms is the
// longest it waits for that frame.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services

PanelWindow {
    id: root

    screen: PickerState.hostScreen

    property bool frameReady: false
    readonly property bool showing: root.frameReady && !PickerState.selectingRegion && !PickerState.finished

    WlrLayershell.namespace: "ionix-share-picker"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Mapped from the start (transparent and input-less until showing), so the
    // cards exist and capture before anything is drawn.
    visible: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // Two explicit regions: going from a mask back to `null` leaves the old one
    // in place (seen in testing: no pointer or keyboard ever arrived).
    mask: root.showing ? fullMask : emptyMask

    Region {
        id: emptyMask
    }

    Region {
        id: fullMask
        item: backdrop
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Timer {
        running: !root.frameReady
        interval: 600
        onTriggered: root.frameReady = true
    }

    onShowingChanged: if (root.showing)
        Qt.callLater(() => keys.forceActiveFocus())

    // Under the blur rule's ignore_alpha (0.2), so only the panel is blurred.
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Theme.alpha(Theme.bgDeep, 0.18)
        opacity: root.showing ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durSlide
            }
        }
    }

    // Swallows clicks on the backdrop so they reach nothing underneath.
    MouseArea {
        anchors.fill: parent
        enabled: root.showing
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (!root.showing)
                return;
            switch (event.key) {
            case Qt.Key_Escape:
                PickerState.cancel();
                break;
            case Qt.Key_Tab:
                PickerState.cyclePage(1);
                break;
            case Qt.Key_Backtab:
                PickerState.cyclePage(-1);
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                if (PickerState.page === "region")
                    PickerState.selectingRegion = true;
                else
                    PickerState.shareSelected();
                break;
            case Qt.Key_Left:
                grid.move(-1);
                break;
            case Qt.Key_Right:
                grid.move(1);
                break;
            case Qt.Key_Up:
                grid.move(-grid.cols);
                break;
            case Qt.Key_Down:
                grid.move(grid.cols);
                break;
            default:
                return;
            }
            event.accepted = true;
        }
    }

    GlassPanel {
        id: panel

        readonly property int bodyWidth: Math.min(1040, Math.max(560, root.width * 0.62))

        anchors.centerIn: parent
        width: panel.bodyWidth + padding * 2
        opacity: root.showing ? 1 : 0
        scale: root.showing ? 1 : 0.96

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durSlide
                easing.type: Theme.easeStandard
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Theme.durSlide
                easing.type: Theme.easeStandard
            }
        }

        Column {
            width: panel.bodyWidth
            spacing: Theme.sp5

            // ── Header ──────────────────────────────────────────────────────
            Row {
                id: header
                width: parent.width
                spacing: Theme.sp4

                Rectangle {
                    width: 40
                    height: 40
                    radius: Theme.rPill
                    color: Theme.alpha(Theme.accentBright, 0.18)

                    Text {
                        anchors.centerIn: parent
                        text: Icons.screenShare
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsIconLg
                        color: Theme.accentLight
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 40 - Theme.sp4
                    spacing: Theme.sp1

                    Text {
                        text: "Share your screen"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsXl
                        font.weight: Font.Bold
                        color: Theme.textBright
                    }

                    Text {
                        width: parent.width
                        text: "An app asked to capture your screen. Pick what it may see; nothing is shared until you press Share."
                        wrapMode: Text.WordWrap
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsMd
                        color: Theme.muted
                    }
                }
            }

            // ── Pages ───────────────────────────────────────────────────────
            Row {
                id: tabs
                spacing: Theme.sp2

                Repeater {
                    model: PickerState.pages

                    delegate: Rectangle {
                        id: tab
                        required property string modelData

                        readonly property bool current: PickerState.page === tab.modelData
                        readonly property string label: ({
                                screens: `Screens  ${PickerState.screens.length}`,
                                windows: `Windows  ${PickerState.windows.length}`,
                                region: "Area"
                            })[tab.modelData]
                        readonly property string glyph: ({
                                screens: Icons.monitor,
                                windows: Icons.window,
                                region: Icons.region
                            })[tab.modelData]

                        width: tabRow.implicitWidth + Theme.sp5 * 2
                        height: 32
                        radius: Theme.rSm
                        color: tab.current ? Theme.alpha(Theme.accentBright, Theme.flat ? 0.22 : 0.85) : (tabMouse.containsMouse ? Theme.subtleHover : "transparent")
                        border.width: tab.current ? 0 : 1
                        border.color: Theme.controlStroke

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.durNormal
                            }
                        }

                        Row {
                            id: tabRow
                            anchors.centerIn: parent
                            spacing: Theme.sp3

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: tab.glyph
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsIcon
                                color: tab.current && !Theme.flat ? Theme.onAccent : Theme.text
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: tab.label
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsBase
                                font.weight: tab.current ? Font.Bold : Font.Medium
                                color: tab.current && !Theme.flat ? Theme.onAccent : Theme.textBright
                            }
                        }

                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: PickerState.page = tab.modelData
                        }
                    }
                }
            }

            // ── Cards ───────────────────────────────────────────────────────
            Item {
                id: grid

                readonly property int gap: Theme.sp4
                readonly property int cols: Math.max(1, Math.floor((width + gap) / (230 + gap)))
                readonly property real cardWidth: (width - (cols - 1) * gap) / cols
                // Cards are 16:10 pictures over a two-line footer.
                readonly property real cardHeight: Math.round((cardWidth - Theme.sp3 * 2) * 10 / 16) + 34 + Theme.sp3 * 2 + Theme.sp2
                readonly property var items: PickerState.page === "screens" ? PickerState.screens : (PickerState.page === "windows" ? PickerState.windows : [])
                readonly property int rows: Math.ceil(items.length / cols)
                readonly property real fullHeight: rows * cardHeight + Math.max(0, rows - 1) * gap
                // What the screen leaves once the header, tabs, footer and the
                // panel's own padding are placed, with a margin above and below.
                readonly property real roomLeft: root.height - Theme.sp7 * 2 - panel.padding * 2 - header.height - tabs.height - footer.height - Theme.sp5 * 3

                width: parent.width
                // Up to two and a half rows, so a long window list shows that it
                // scrolls, and never more than the screen has room for.
                height: PickerState.page === "region" ? regionPage.implicitHeight : Math.max(cardHeight * 0.6, Math.min(fullHeight, cardHeight * 2.5 + gap * 2, roomLeft))

                function move(step) {
                    const n = grid.items.length;
                    if (n === 0)
                        return;
                    if (PickerState.page === "screens")
                        PickerState.selectScreen(Math.max(0, Math.min(n - 1, PickerState.screenIndex + step)));
                    else if (PickerState.page === "windows")
                        PickerState.selectWindow(Math.max(0, Math.min(n - 1, PickerState.windowIndex + step)));
                    flick.reveal();
                }

                Flickable {
                    id: flick
                    anchors.fill: parent
                    visible: PickerState.page !== "region"
                    clip: true
                    contentWidth: width
                    contentHeight: grid.fullHeight
                    boundsBehavior: Flickable.StopAtBounds

                    // Keeps the keyboard's card on screen.
                    function reveal() {
                        const index = PickerState.page === "screens" ? PickerState.screenIndex : PickerState.windowIndex;
                        const top = Math.floor(index / grid.cols) * (grid.cardHeight + grid.gap);
                        if (top < contentY)
                            contentY = top;
                        else if (top + grid.cardHeight > contentY + height)
                            contentY = top + grid.cardHeight - height;
                    }

                    // Screens. Hidden rather than destroyed on the other pages: a
                    // rebuilt host card would take its still again, this time with
                    // the dialog in it.
                    Flow {
                        width: flick.width
                        spacing: grid.gap
                        visible: PickerState.page === "screens"

                        Repeater {
                            model: PickerState.screens

                            delegate: SourceCard {
                                id: screenCard
                                required property var modelData
                                required property int index

                                readonly property bool isHost: modelData.name === PickerState.hostName

                                width: grid.cardWidth
                                height: grid.cardHeight
                                source: modelData
                                live: !screenCard.isHost && Config.picker.livePreviews && PickerState.page === "screens"
                                glyph: Icons.monitor
                                title: modelData.model ? `${modelData.name} · ${modelData.model}` : modelData.name
                                subtitle: `${modelData.width} × ${modelData.height}`
                                chip: screenCard.isHost ? "This screen" : ""
                                selected: index === PickerState.screenIndex
                                onClicked: PickerState.selectScreen(index)
                                onDoubleClicked: PickerState.shareScreen(modelData)

                                onHasFrameChanged: if (hasFrame && isHost)
                                    root.frameReady = true
                            }
                        }
                    }

                    // Windows. Their streams stop while another page is up.
                    Flow {
                        width: flick.width
                        spacing: grid.gap
                        visible: PickerState.page === "windows"

                        Repeater {
                            model: PickerState.windows

                            delegate: SourceCard {
                                id: windowCard
                                required property var modelData
                                required property int index

                                readonly property var ws: modelData.toplevel?.workspace ?? null

                                width: grid.cardWidth
                                height: grid.cardHeight
                                source: modelData.toplevel?.wayland ?? null
                                live: Config.picker.livePreviews && PickerState.page === "windows"
                                iconName: modelData.toplevel ? Windows.iconFor(modelData.toplevel) : (DesktopEntries.heuristicLookup(modelData.appClass)?.icon ?? "")
                                title: modelData.title !== "" ? modelData.title : modelData.appClass
                                subtitle: modelData.appClass
                                chip: windowCard.desktopLabel(windowCard.ws)
                                selected: index === PickerState.windowIndex
                                onClicked: PickerState.selectWindow(index)
                                onDoubleClicked: PickerState.shareWindow(modelData)

                                function desktopLabel(ws) {
                                    if (!ws)
                                        return "";
                                    if (ws.id < 0)
                                        return ws.name === "special" || ws.name === "special:special" ? "Minimized" : "Scratchpad";
                                    return String(ws.name) === String(ws.id) ? `Desktop ${ws.id}` : ws.name;
                                }
                            }
                        }
                    }
                }

                // ── Area ────────────────────────────────────────────────────
                Column {
                    id: regionPage
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: PickerState.page === "region"
                    width: Math.min(parent.width, 520)
                    spacing: Theme.sp4
                    topPadding: Theme.sp6
                    bottomPadding: Theme.sp6

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Icons.region
                        font.family: Theme.fontFamily
                        font.pixelSize: 56
                        color: Theme.alpha(Theme.accentLight, 0.85)
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: "Share part of a screen"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsLg
                        font.weight: Font.Bold
                        color: Theme.textBright
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: "Drag a rectangle over any screen. The area stays on the screen you start on; Esc comes back here."
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsMd
                        color: Theme.muted
                    }

                    PickerButton {
                        anchors.horizontalCenter: parent.horizontalCenter
                        primary: true
                        glyph: Icons.region
                        text: "Select an area"
                        hint: "Enter"
                        onClicked: PickerState.selectingRegion = true
                    }
                }
            }

            // ── Footer ──────────────────────────────────────────────────────
            Item {
                id: footer
                width: parent.width
                height: 36

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.sp3

                    Switch {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: PickerState.allowToken
                        onToggled: value => PickerState.allowToken = value
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Remember this choice for the app"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsMd
                        color: Theme.text

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: PickerState.allowToken = !PickerState.allowToken
                        }
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.sp3

                    PickerButton {
                        text: "Cancel"
                        hint: "Esc"
                        onClicked: PickerState.cancel()
                    }

                    PickerButton {
                        visible: PickerState.page !== "region"
                        primary: true
                        glyph: Icons.screenShare
                        text: "Share"
                        hint: "Enter"
                        enabled: PickerState.canShare
                        onClicked: PickerState.shareSelected()
                    }
                }
            }
        }
    }
}
