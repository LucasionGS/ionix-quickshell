// Every global keyboard shortcut Hyprland has, in a panel over the dimmed desktop. One
// overlay per screen, only the focused one showing anything. The list itself comes
// from services/Shortcuts.
//
// Typing filters at once, by what a shortcut does or by its keys. The arrow keys and
// the wheel scroll; a click outside the panel, or Escape, closes it. Everything it
// paints comes from the theme.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.services

PanelWindow {
    id: root

    required property var modelData
    screen: root.modelData

    readonly property bool showing: Shortcuts.active && Hyprland.focusedMonitor?.name === root.modelData.name

    property string query: ""

    readonly property int minColumnWidth: 380
    readonly property int columnGap: Theme.sp7
    readonly property int columnCount: Math.max(1, Math.floor((list.width + root.columnGap) / (root.minColumnWidth + root.columnGap)))
    readonly property real columnWidth: (list.width - root.columnGap * (root.columnCount - 1)) / root.columnCount

    // Every word has to be somewhere in the row, so "super tab" finds it.
    readonly property var visibleSections: {
        const words = root.query.trim().toLowerCase().split(/\s+/).filter(w => w !== "");
        if (words.length === 0)
            return Shortcuts.sections;
        return Shortcuts.sections.map(section => ({
                    title: section.title,
                    rows: section.rows.filter(row => {
                        const haystack = row.haystack.toLowerCase();
                        return words.every(w => haystack.includes(w));
                    })
                })).filter(section => section.rows.length > 0);
    }

    // Biggest sections first, each to whichever column is shortest so far, so they end
    // level without a section being split across two. Each column then reads in the
    // order Hyprland has them.
    readonly property var columns: {
        const lines = section => 2 + section.rows.reduce((sum, row) => sum + row.chords.length, 0);
        const order = root.visibleSections.map((section, index) => ({
                    section,
                    index
                }));
        const columns = [];
        const heights = [];
        for (let i = 0; i < root.columnCount; i++) {
            columns.push([]);
            heights.push(0);
        }
        for (const item of order.slice().sort((a, b) => lines(b.section) - lines(a.section))) {
            const shortest = heights.indexOf(Math.min(...heights));
            columns[shortest].push(item);
            heights[shortest] += lines(item.section);
        }
        return columns.map(column => column.sort((a, b) => a.index - b.index).map(item => item.section));
    }

    WlrLayershell.namespace: "ionix-shortcuts"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    visible: root.showing || fadeHold.running
    focusable: root.showing
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Timer {
        id: fadeHold
        interval: Theme.durSlide
    }

    onShowingChanged: {
        if (!root.showing) {
            fadeHold.restart();
            return;
        }
        root.query = "";
        list.contentY = 0;
        Qt.callLater(() => field.forceActiveFocus());
    }

    onQueryChanged: list.contentY = 0

    function scroll(delta) {
        const bottom = Math.max(0, list.contentHeight - list.height);
        list.contentY = Math.max(0, Math.min(bottom, list.contentY + delta));
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.bgDeep, 0.5)
        opacity: root.showing ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: root.showing ? Theme.durSlow : Theme.durSlide
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Shortcuts.close()
    }

    Rectangle {
        id: panel
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        width: Math.min(parent.width - 2 * Theme.sp7, 1280)
        height: Math.min(parent.height - 2 * Theme.sp7, header.height + list.contentHeight + 3 * Theme.sp6)
        radius: Theme.rPanel
        color: Theme.panelFill
        border.width: 1
        border.color: Theme.panelBorder
        opacity: root.showing ? 1 : 0
        scale: root.showing ? 1 : 1.03

        Behavior on opacity {
            NumberAnimation {
                duration: root.showing ? Theme.durSlow : Theme.durSlide
                easing.type: Theme.easeStandard
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: root.showing ? Theme.durSlow : Theme.durSlide
                easing.type: Theme.easeStandard
            }
        }

        // A click on the panel is not a click outside it.
        MouseArea {
            anchors.fill: parent
        }

        // ── Header ──────────────────────────────────────────────────────────
        Item {
            id: header
            x: Theme.sp6
            y: Theme.sp6
            width: parent.width - 2 * Theme.sp6
            height: 30

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Keyboard shortcuts"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsXl
                font.weight: Font.DemiBold
                color: Theme.textBright
            }

            Rectangle {
                anchors.right: parent.right
                width: 280
                height: parent.height
                radius: Theme.rSm
                color: Theme.fieldFill
                border.width: 1
                border.color: Theme.controlStroke

                Text {
                    id: magnifier
                    x: Theme.sp3
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.search
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsIcon
                    color: Theme.muted
                }

                Text {
                    anchors.left: magnifier.right
                    anchors.leftMargin: Theme.sp3
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.query === ""
                    text: "Search"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsBase
                    color: Theme.muted
                }

                TextInput {
                    id: field
                    anchors.left: magnifier.right
                    anchors.leftMargin: Theme.sp3
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.sp3
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.query
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsBase
                    color: Theme.textBright
                    selectionColor: Theme.accent
                    clip: true
                    onTextEdited: root.query = text

                    Keys.onPressed: event => {
                        switch (event.key) {
                        case Qt.Key_Escape:
                            if (root.query !== "")
                                root.query = "";
                            else
                                Shortcuts.close();
                            break;
                        case Qt.Key_Up:
                            root.scroll(-60);
                            break;
                        case Qt.Key_Down:
                            root.scroll(60);
                            break;
                        case Qt.Key_PageUp:
                            root.scroll(-list.height * 0.9);
                            break;
                        case Qt.Key_PageDown:
                            root.scroll(list.height * 0.9);
                            break;
                        default:
                            return;
                        }
                        event.accepted = true;
                    }
                }
            }
        }

        // ── List ────────────────────────────────────────────────────────────
        Flickable {
            id: list
            x: Theme.sp6
            y: header.y + header.height + Theme.sp6
            width: parent.width - 2 * Theme.sp6
            height: parent.height - y - Theme.sp6
            contentWidth: width
            contentHeight: root.visibleSections.length > 0 ? columnRow.height : empty.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Text {
                id: empty
                width: parent.width
                visible: root.visibleSections.length === 0
                horizontalAlignment: Text.AlignHCenter
                text: root.query === "" ? "Hyprland reported no shortcuts." : "No shortcut matches that."
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsBase
                color: Theme.muted
            }

            Row {
                id: columnRow
                spacing: root.columnGap

                Repeater {
                    // Drawn only while up: this is a keycap per key of every bind.
                    model: root.visible ? root.columns : []

                    delegate: Column {
                        id: column
                        required property var modelData

                        width: root.columnWidth
                        spacing: Theme.sp6

                        Repeater {
                            model: column.modelData

                            delegate: Column {
                                id: sectionBlock
                                required property var modelData

                                width: column.width
                                spacing: Theme.sp3

                                Text {
                                    text: sectionBlock.modelData.title
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsMd
                                    font.weight: Font.DemiBold
                                    color: Theme.accentLight
                                }

                                Repeater {
                                    model: sectionBlock.modelData.rows

                                    delegate: ShortcutRow {
                                        required property var modelData
                                        width: sectionBlock.width
                                        row: modelData
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Pieces ──────────────────────────────────────────────────────────────

    // What it does on the left, each way of doing it on the right.
    component ShortcutRow: Item {
        id: shortcutRow

        property var row

        implicitHeight: Math.max(label.implicitHeight, chords.implicitHeight)

        Column {
            id: chords
            anchors.right: parent.right
            spacing: Theme.sp2

            Repeater {
                model: shortcutRow.row.chords

                delegate: Row {
                    id: chord
                    required property var modelData

                    anchors.right: parent.right
                    spacing: Theme.sp2

                    Repeater {
                        model: chord.modelData.mods

                        delegate: Row {
                            required property string modelData
                            spacing: Theme.sp2

                            KeyCap {
                                label: parent.modelData
                            }
                            KeyGap {
                                text: "+"
                            }
                        }
                    }

                    Repeater {
                        model: chord.modelData.caps

                        delegate: Row {
                            required property string modelData
                            required property int index
                            spacing: Theme.sp2

                            KeyGap {
                                visible: parent.index > 0
                                text: chord.modelData.separator
                            }
                            KeyCap {
                                label: parent.modelData
                            }
                        }
                    }
                }
            }
        }

        Text {
            id: label
            anchors.left: parent.left
            anchors.right: chords.left
            anchors.rightMargin: Theme.sp4
            text: shortcutRow.row.text
            wrapMode: Text.Wrap
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsBase
            color: Theme.text
        }
    }

    component KeyCap: Rectangle {
        property alias label: capText.text

        width: Math.max(height, capText.implicitWidth + 2 * Theme.sp3)
        height: 20
        radius: Math.min(Theme.rSm, 5)
        color: Theme.controlFill
        border.width: 1
        border.color: Theme.controlStroke

        Text {
            id: capText
            anchors.centerIn: parent
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsSm
            color: Theme.textBright
        }
    }

    component KeyGap: Text {
        height: 20
        verticalAlignment: Text.AlignVCenter
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fsSm
        color: Theme.muted
    }
}
