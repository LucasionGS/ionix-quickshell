// Every installed application as a page of big icons over the blurred desktop, with a
// search field on top. One overlay per screen, only the focused one showing anything.
//
// Typing filters at once, so it doubles as a launcher: Enter starts the first match.
// Scroll or the arrow keys turn the page; a click on nothing, or Escape, closes it.
// Everything it paints comes from the theme.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs.config
import qs.services

PanelWindow {
    id: root

    required property var modelData
    screen: root.modelData

    readonly property bool showing: AppGrid.active && Hyprland.focusedMonitor?.name === root.modelData.name

    property string query: ""
    property int page: 0
    // The keyboard's tile, an index into `apps`.
    property int selection: 0

    readonly property var apps: {
        const q = root.query.trim();
        if (q === "")
            return Apps.list;
        return Apps.list.map(entry => ({
                    entry,
                    score: Apps.score(entry, q)
                })).filter(row => row.score > 0).sort((a, b) => b.score - a.score).map(row => row.entry);
    }

    // ── Layout ──────────────────────────────────────────────────────────────
    readonly property int iconSize: Config.appGrid.iconSize
    readonly property int tileWidth: Math.floor(Math.min(root.iconSize * 2.4, (root.width - 160) / root.columns))
    readonly property int tileHeight: root.iconSize + 56
    readonly property int columns: Config.appGrid.columns
    readonly property int headerHeight: 96
    readonly property int footerHeight: 48
    readonly property int rows: Math.max(1, Math.min(Config.appGrid.rows, Math.floor((root.height - root.headerHeight - root.footerHeight) / root.tileHeight)))
    readonly property int perPage: root.columns * root.rows
    readonly property int pageCount: Math.max(1, Math.ceil(root.apps.length / root.perPage))

    WlrLayershell.namespace: "ionix-appgrid"
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
        root.page = 0;
        root.selection = 0;
        Qt.callLater(() => field.forceActiveFocus());
    }

    onQueryChanged: {
        root.page = 0;
        root.selection = 0;
    }

    function start(entry) {
        Apps.launch(entry);
        AppGrid.close();
    }

    function turn(delta) {
        const next = Math.max(0, Math.min(root.pageCount - 1, root.page + delta));
        if (next === root.page)
            return;
        root.page = next;
        root.selection = next * root.perPage;
    }

    function move(delta) {
        const next = Math.max(0, Math.min(root.apps.length - 1, root.selection + delta));
        root.selection = next;
        root.page = Math.floor(next / root.perPage);
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
        onClicked: AppGrid.close()
        onWheel: event => root.turn(event.angleDelta.y > 0 ? -1 : 1)
    }

    Item {
        anchors.fill: parent
        opacity: root.showing ? 1 : 0
        scale: root.showing ? 1 : 1.06

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

        // ── Search ──────────────────────────────────────────────────────────
        Rectangle {
            id: searchBox
            x: (parent.width - width) / 2
            y: 40
            width: 280
            height: 30
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
                            AppGrid.close();
                        break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        if (root.apps[root.selection])
                            root.start(root.apps[root.selection]);
                        break;
                    case Qt.Key_Left:
                        root.move(-1);
                        break;
                    case Qt.Key_Right:
                    case Qt.Key_Tab:
                        root.move(1);
                        break;
                    case Qt.Key_Up:
                        root.move(-root.columns);
                        break;
                    case Qt.Key_Down:
                        root.move(root.columns);
                        break;
                    case Qt.Key_PageUp:
                        root.turn(-1);
                        break;
                    case Qt.Key_PageDown:
                        root.turn(1);
                        break;
                    default:
                        return;
                    }
                    event.accepted = true;
                }
            }
        }

        // ── Pages ───────────────────────────────────────────────────────────
        Item {
            id: pager
            anchors.fill: parent
            anchors.topMargin: root.headerHeight
            anchors.bottomMargin: root.footerHeight
            clip: true

            Row {
                x: -root.page * pager.width
                height: parent.height

                Behavior on x {
                    NumberAnimation {
                        duration: Theme.durSlow
                        easing.type: Theme.easeStandard
                    }
                }

                Repeater {
                    // Drawn only while up: this is one icon per installed app.
                    model: root.showing || fadeHold.running ? root.pageCount : 0

                    delegate: Item {
                        id: pageItem
                        required property int index

                        width: pager.width
                        height: pager.height

                        Grid {
                            anchors.centerIn: parent
                            columns: root.columns

                            Repeater {
                                model: root.apps.slice(pageItem.index * root.perPage, (pageItem.index + 1) * root.perPage)

                                delegate: Item {
                                    id: tile
                                    required property var modelData
                                    required property int index

                                    readonly property bool selected: root.query !== "" && root.selection === pageItem.index * root.perPage + tile.index
                                    readonly property string iconSource: Apps.iconSource(tile.modelData)

                                    width: root.tileWidth
                                    height: root.tileHeight

                                    Rectangle {
                                        x: (parent.width - width) / 2
                                        y: 2
                                        width: root.iconSize + Theme.sp5
                                        height: root.iconSize + Theme.sp5
                                        radius: Theme.rPanel
                                        color: tileMouse.pressed || tile.selected ? Theme.subtleHover : "transparent"
                                    }

                                    IconImage {
                                        x: (parent.width - width) / 2
                                        y: Theme.sp2 + Theme.sp3
                                        width: root.iconSize
                                        height: root.iconSize
                                        visible: tile.iconSource !== ""
                                        source: tile.iconSource
                                        asynchronous: true
                                        scale: tileMouse.pressed ? 0.92 : 1
                                    }

                                    // First letter when the app has no themed icon.
                                    Rectangle {
                                        x: (parent.width - width) / 2
                                        y: Theme.sp2 + Theme.sp3
                                        width: root.iconSize
                                        height: root.iconSize
                                        visible: tile.iconSource === ""
                                        radius: Theme.rPanel
                                        color: Theme.controlFill

                                        Text {
                                            anchors.centerIn: parent
                                            text: (tile.modelData.name ?? "?").charAt(0).toUpperCase()
                                            font.family: Theme.fontFamily
                                            font.pixelSize: root.iconSize / 2
                                            font.weight: Font.DemiBold
                                            color: Theme.textBright
                                        }
                                    }

                                    Text {
                                        x: Theme.sp2
                                        y: root.iconSize + Theme.sp6
                                        width: parent.width - Theme.sp2 * 2
                                        horizontalAlignment: Text.AlignHCenter
                                        text: tile.modelData.name ?? ""
                                        elide: Text.ElideRight
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsBase
                                        color: Theme.textBright
                                    }

                                    MouseArea {
                                        id: tileMouse
                                        anchors.fill: parent
                                        onClicked: root.start(tile.modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.apps.length === 0
                text: `No apps match “${root.query}”`
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsXl
                color: Theme.textBright
            }
        }

        // ── Page dots ───────────────────────────────────────────────────────
        Row {
            x: (parent.width - width) / 2
            y: parent.height - root.footerHeight + (root.footerHeight - height) / 2 - Theme.sp4
            spacing: Theme.sp3
            visible: root.pageCount > 1

            Repeater {
                model: root.pageCount

                delegate: Rectangle {
                    required property int index
                    width: 8
                    height: 8
                    radius: 4
                    color: Theme.textBright
                    opacity: index === root.page ? 1 : 0.35

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -Theme.sp2
                        onClicked: root.page = parent.index
                    }
                }
            }
        }
    }
}
