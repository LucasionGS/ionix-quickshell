// Task View: the open windows of the current workspace as thumbnails, with a strip
// of every workspace along the bottom. One overlay per screen, only the focused one
// showing anything.
//
// Built on the same cards and the same keyboard-grab recipe as SwitcherOverlay, but
// it stays up until something is picked: there is no held Alt to let go of. Unlike
// that one it keeps clear of the bar, whichever edge the bar is on, so the button
// that opened it can close it again. Everything it paints comes from the theme.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services

PanelWindow {
    id: root

    required property var modelData
    screen: root.modelData

    readonly property bool showing: TaskView.active && Hyprland.focusedMonitor?.name === root.modelData.name
    readonly property int activeId: Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1
    readonly property var windows: Windows.toplevels.filter(t => t.workspace?.id === root.activeId && t.monitor?.name === root.modelData.name)
    readonly property var desktops: Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor?.name === root.modelData.name).sort((a, b) => a.id - b.id)

    // The keyboard's card, an index into `windows`.
    property int selection: 0

    // Changing workspace hands Hyprland's keyboard focus to a window there, past even
    // an exclusive layer, and it stays there: Escape would reach that window instead.
    // Letting go and asking again is what brings it back.
    property bool regrabbing: false

    onActiveIdChanged: {
        if (root.showing) {
            root.regrabbing = true;
            regrab.restart();
        }
    }

    Timer {
        id: regrab
        interval: 50
        onTriggered: {
            root.regrabbing = false;
            Qt.callLater(() => keys.forceActiveFocus());
        }
    }

    // ── Layout ──────────────────────────────────────────────────────────────
    readonly property int edgeGap: Theme.sp7
    readonly property int cardGap: Theme.sp5
    readonly property int stripHeight: 112
    readonly property int footerHeight: 34
    readonly property int areaWidth: Math.max(0, root.width - root.edgeGap * 2)
    readonly property int areaHeight: Math.max(0, root.height - root.stripHeight - root.edgeGap * 3)
    readonly property real aspect: root.modelData.width / Math.max(1, root.modelData.height)

    // However many columns make the cards largest in the space there is. Past
    // maxCardWidth a lone window would fill the screen, which is not an overview.
    readonly property var fit: {
        const count = Math.max(1, root.windows.length);
        let best = {
            columns: 1,
            width: 0
        };
        for (let columns = 1; columns <= count; columns++) {
            const rows = Math.ceil(count / columns);
            const byWidth = (root.areaWidth - root.cardGap * (columns - 1)) / columns;
            const byHeight = ((root.areaHeight - root.cardGap * (rows - 1)) / rows - root.footerHeight) * root.aspect;
            const width = Math.floor(Math.min(byWidth, byHeight, Config.taskView.maxCardWidth));
            if (width > best.width)
                best = {
                    columns: columns,
                    width: width
                };
        }
        return best;
    }
    readonly property int cardWidth: Math.max(1, root.fit.width)
    readonly property int cardHeight: Math.round(root.cardWidth / root.aspect) + root.footerHeight

    readonly property var rows: {
        const out = [];
        for (let i = 0; i < root.windows.length; i += root.fit.columns)
            out.push(root.windows.slice(i, i + root.fit.columns).map((toplevel, n) => ({
                            toplevel: toplevel,
                            index: i + n
                        })));
        return out;
    }

    // Narrows when there are more workspaces than the strip holds at full width.
    readonly property int tileWidth: Math.min(180, Math.floor((root.areaWidth - Theme.sp4 * root.desktops.length) / (root.desktops.length + 1)))

    WlrLayershell.namespace: "ionix-taskview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.showing && !root.regrabbing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    visible: root.showing || fadeHold.running
    focusable: root.showing
    exclusionMode: ExclusionMode.Normal
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Timer {
        id: fadeHold
        interval: Theme.durFast
    }

    onShowingChanged: {
        if (!root.showing) {
            fadeHold.restart();
            return;
        }
        root.selection = Math.max(0, root.windows.findIndex(w => w.activated));
        // The strip's miniatures read each window's position, which the toplevel
        // list only carries once asked for.
        Hyprland.refreshToplevels();
        Qt.callLater(() => keys.forceActiveFocus());
    }

    function pick(toplevel) {
        Windows.activate(toplevel);
        TaskView.close();
    }

    // Heavy enough, with the compositor's blur, to turn the desktop into a backdrop.
    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.bgDeep, 0.72)
        opacity: root.showing ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: root.showing ? Theme.durSlide : Theme.durFast
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: TaskView.close()
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            const count = root.windows.length;
            const columns = root.fit.columns;
            let next = root.selection;
            switch (event.key) {
            case Qt.Key_Escape:
                TaskView.close();
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                if (root.windows[root.selection])
                    root.pick(root.windows[root.selection]);
                break;
            case Qt.Key_Left:
                next--;
                break;
            case Qt.Key_Right:
            case Qt.Key_Tab:
                next++;
                break;
            case Qt.Key_Up:
                next -= columns;
                break;
            case Qt.Key_Down:
                next += columns;
                break;
            default:
                return;
            }
            if (count > 0 && next !== root.selection)
                root.selection = Math.max(0, Math.min(count - 1, next));
            event.accepted = true;
        }
    }

    Item {
        anchors.fill: parent
        opacity: root.showing ? 1 : 0
        scale: root.showing ? 1 : 0.98

        Behavior on opacity {
            NumberAnimation {
                duration: root.showing ? Theme.durSlide : Theme.durFast
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: root.showing ? Theme.durSlide : Theme.durFast
                easing.type: Theme.easeStandard
            }
        }

        // ── Windows ─────────────────────────────────────────────────────────
        Column {
            x: (parent.width - width) / 2
            y: root.edgeGap + Math.max(0, (root.areaHeight - height) / 2)
            spacing: root.cardGap

            Repeater {
                model: root.showing ? root.rows : []

                delegate: Row {
                    id: cardRow
                    required property var modelData

                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: root.cardGap

                    Repeater {
                        model: cardRow.modelData

                        delegate: Item {
                            id: entry
                            required property var modelData

                            width: root.cardWidth
                            height: root.cardHeight

                            WindowPreviewCard {
                                id: card
                                anchors.fill: parent
                                toplevel: entry.modelData.toplevel
                                selected: entry.modelData.index === root.selection
                                onActivated: root.pick(entry.modelData.toplevel)
                            }

                            Rectangle {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: Theme.sp2
                                width: 28
                                height: 28
                                radius: Theme.rSm
                                visible: card.hovered || closeMouse.containsMouse
                                color: closeMouse.containsMouse ? Theme.closeHover : Theme.alpha(Theme.bgDeep, 0.7)

                                Text {
                                    anchors.centerIn: parent
                                    text: Icons.close
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsMd
                                    color: Theme.textBright
                                }

                                MouseArea {
                                    id: closeMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: Windows.close(entry.modelData.toplevel)
                                }
                            }
                        }
                    }
                }
            }
        }

        Text {
            x: (parent.width - width) / 2
            y: root.edgeGap + (root.areaHeight - height) / 2
            visible: root.windows.length === 0
            text: "No open windows on this desktop"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsXl
            color: Theme.muted
        }

        // ── Desktops ────────────────────────────────────────────────────────
        Row {
            x: (parent.width - width) / 2
            y: parent.height - height - root.edgeGap
            height: root.stripHeight
            spacing: Theme.sp4

            Repeater {
                model: root.showing ? root.desktops : []

                delegate: Rectangle {
                    id: desktop
                    required property var modelData
                    readonly property bool current: desktop.modelData.id === root.activeId
                    readonly property var members: Windows.toplevels.filter(t => t.workspace?.id === desktop.modelData.id)

                    width: root.tileWidth
                    height: root.stripHeight
                    radius: Theme.rPanel
                    color: deskMouse.containsMouse ? Theme.subtleHover : Theme.controlFill
                    border.width: desktop.current ? 2 : 1
                    border.color: desktop.current ? Theme.accentBright : Theme.controlStroke

                    // The workspace in miniature: each window where it really is,
                    // with its icon. The screen's own proportions, letterboxed.
                    Item {
                        id: miniature
                        readonly property real fit: Math.min((desktop.width - Theme.sp4 * 2) / root.modelData.width, (desktop.height - 34) / root.modelData.height)
                        x: (desktop.width - width) / 2
                        y: Theme.sp3
                        width: root.modelData.width * fit
                        height: root.modelData.height * fit
                        clip: true

                        Repeater {
                            model: desktop.members

                            delegate: Rectangle {
                                id: mini
                                required property var modelData

                                readonly property var info: mini.modelData.lastIpcObject
                                readonly property var at: mini.info?.at ?? [0, 0]
                                readonly property var size: mini.info?.size ?? [root.modelData.width, root.modelData.height]
                                readonly property string iconName: Windows.iconFor(mini.modelData)

                                x: (mini.at[0] - root.modelData.x) * miniature.fit
                                y: (mini.at[1] - root.modelData.y) * miniature.fit
                                width: mini.size[0] * miniature.fit
                                height: mini.size[1] * miniature.fit
                                radius: Math.min(Theme.rSm, 4)
                                color: Theme.alpha(Theme.text, 0.14)
                                border.width: 1
                                border.color: Theme.alpha(Theme.text, 0.28)

                                IconImage {
                                    anchors.centerIn: parent
                                    readonly property int side: Math.min(16, parent.width - 4, parent.height - 4)
                                    visible: mini.iconName !== "" && side >= 8
                                    width: side
                                    height: side
                                    source: mini.iconName === "" ? "" : Quickshell.iconPath(mini.iconName)
                                    asynchronous: true
                                }
                            }
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.margins: Theme.sp3
                        width: parent.width - Theme.sp3 * 2
                        elide: Text.ElideRight
                        // A project workspace keeps its label; the rest get a plain name.
                        text: desktop.modelData.name === String(desktop.modelData.id) ? `Desktop ${desktop.modelData.id}` : desktop.modelData.name
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsSm
                        color: Theme.textBright
                    }

                    MouseArea {
                        id: deskMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: TaskView.goTo(desktop.modelData.id)
                    }
                }
            }

            Rectangle {
                width: root.tileWidth
                height: root.stripHeight
                radius: Theme.rPanel
                color: newMouse.containsMouse ? Theme.subtleHover : "transparent"
                border.width: 1
                border.color: Theme.controlStroke

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.sp2

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Icons.plus
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsIconLg
                        color: Theme.textBright
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "New desktop"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsSm
                        color: Theme.textBright
                    }
                }

                MouseArea {
                    id: newMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: TaskView.newDesktop(root.desktops)
                }
            }
        }
    }
}
