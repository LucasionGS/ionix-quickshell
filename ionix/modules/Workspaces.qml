// Workspace dots for this monitor, with one accent blob sliding to the active one.
//
// A project workspace (services/Projects.qml) also prints its label beside the
// dot on a horizontal bar. The label only widens the dot, so the blob, which
// reads each dot's width, slides and stretches over it with no extra wiring.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property var bar: null
    readonly property var monitor: root.bar?.screen ? Hyprland.monitorFor(root.bar.screen) : null

    // Only this monitor's workspaces. Hyprland hands a workspace to whichever
    // monitor it was created on, so without a filter every bar shows every
    // workspace and clicking one yanks it to another screen.
    //
    // IDs are a single pool shared across monitors and are therefore sparse per
    // monitor (one screen may own 2, 5 and 8). That is why `persistent` padding is
    // off by default: with dynamically assigned workspaces there is no such thing
    // as "this monitor's empty workspace 4" — the ID belongs to whichever screen
    // creates it first. Set `persistent` only alongside per-monitor workspace
    // rules (nwg-displays writes them to ~/.config/hypr/workspaces.lua), where a
    // fixed range really does belong to one monitor.
    readonly property var items: {
        const monitorName = root.monitor?.name ?? "";

        const live = Hyprland.workspaces.values.filter(w => {
            if (w.id < 0)
                return false;      // special workspaces
            if (monitorName === "")
                return false;
            return w.monitor?.name === monitorName;
        });

        const byId = {};
        for (const w of live)
            byId[w.id] = w;

        const result = [];
        const persistent = Config.workspaces.persistent;
        const ids = live.map(w => w.id).sort((a, b) => a - b);

        // Pad only up to `persistent`, and only with IDs no other monitor already
        // owns, so a padded slot can never duplicate a workspace shown elsewhere.
        if (persistent > 0 && Config.workspaces.showEmpty) {
            const takenElsewhere = {};
            for (const w of Hyprland.workspaces.values)
                if (w.id > 0 && w.monitor?.name !== monitorName)
                    takenElsewhere[w.id] = true;

            for (let i = 1; i <= persistent; i++)
                if (!byId[i] && !takenElsewhere[i])
                    ids.push(i);
        }

        for (const id of [...new Set(ids)].sort((a, b) => a - b)) {
            const w = byId[id];
            result.push({
                id: id,
                workspace: w ?? null,
                occupied: w ? w.toplevels.values.length > 0 : false,
                active: w ? w.active : false,
                urgent: w ? w.urgent : false
            });
        }
        return result;
    }

    readonly property int activeIndex: root.items.findIndex(i => i.active)
    readonly property bool vertical: Config.barVertical

    // Thickness of the dot strip on the bar's short axis, the same either way.
    readonly property int lane: Theme.pillHeight - 8

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight

    Pill {
        id: pill
        anchors.fill: parent
        vertical: root.vertical
        padding: Theme.sp2

        Item {
            implicitWidth: root.vertical ? root.lane : dotsRow.width
            implicitHeight: root.vertical ? dotsRow.height : root.lane
            width: implicitWidth
            height: implicitHeight

            // Single blob rather than a border per item: one thing to animate, and
            // it reads as the indicator moving rather than two things blinking.
            SlidingIndicator {
                vertical: root.vertical
                active: root.activeIndex >= 0
                targetX: {
                    if (root.vertical || root.activeIndex < 0)
                        return 0;
                    return dots.itemAt(root.activeIndex)?.x ?? 0;
                }
                targetY: {
                    if (!root.vertical || root.activeIndex < 0)
                        return 0;
                    return dots.itemAt(root.activeIndex)?.y ?? 0;
                }
                targetWidth: {
                    if (root.vertical)
                        return root.lane;
                    if (root.activeIndex < 0)
                        return 0;
                    return dots.itemAt(root.activeIndex)?.width ?? 0;
                }
                targetHeight: {
                    if (!root.vertical)
                        return root.lane;
                    if (root.activeIndex < 0)
                        return 0;
                    return dots.itemAt(root.activeIndex)?.height ?? 0;
                }
            }

            Grid {
                id: dotsRow
                rows: root.vertical ? Math.max(1, root.items.length) : 1
                columns: root.vertical ? 1 : Math.max(1, root.items.length)
                horizontalItemAlignment: Grid.AlignHCenter
                verticalItemAlignment: Grid.AlignVCenter
                spacing: 0

                Repeater {
                    id: dots
                    model: root.items

                    delegate: Item {
                        id: dot
                        required property var modelData
                        required property int index

                        readonly property bool isActive: modelData.active
                        readonly property bool hovered: dotMouse.containsMouse
                        readonly property string project: Projects.labelFor(modelData.workspace)
                        // Sideways text on a vertical bar would be unreadable at
                        // this size; there the label lives in the tooltip only.
                        readonly property bool showsLabel: dot.project !== "" && Config.workspaces.showLabels && !root.vertical
                        readonly property color tint: {
                            if (dot.modelData.urgent)
                                return Theme.orange;
                            if (dot.isActive)
                                return Theme.textBright;
                            if (dot.hovered)
                                return Theme.accentLight;
                            return dot.modelData.occupied ? Theme.text : Theme.border;
                        }

                        // The dot grows along the bar's long axis; the other axis
                        // is the lane. 34/26/20 read as active / has windows /
                        // empty without needing a second cue.
                        readonly property int span: dot.showsLabel ? dotContent.implicitWidth + Theme.sp4 : (isActive ? 34 : (modelData.occupied ? 26 : 20))

                        width: root.vertical ? root.lane : span
                        height: root.vertical ? span : root.lane

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.durSlide
                                easing.type: Theme.easeStandard
                            }
                        }
                        Behavior on height {
                            NumberAnimation {
                                duration: Theme.durSlide
                                easing.type: Theme.easeStandard
                            }
                        }

                        Row {
                            id: dotContent
                            anchors.centerIn: parent
                            spacing: Theme.sp1

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: {
                                    if (dot.modelData.urgent)
                                        return Icons.wsUrgent;
                                    if (dot.isActive)
                                        return Icons.wsActive;
                                    return dot.modelData.occupied ? Icons.wsOccupied : Icons.wsEmpty;
                                }
                                font.family: Theme.fontFamily
                                font.pixelSize: dot.isActive ? Theme.fsMd : Theme.fsSm
                                color: dot.tint
                                scale: dot.isActive ? 1.15 : 1.0

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.durNormal
                                    }
                                }
                                Behavior on scale {
                                    NumberAnimation {
                                        duration: Theme.durNormal
                                        easing.type: Theme.easeOvershoot
                                    }
                                }

                                SequentialAnimation on opacity {
                                    running: dot.modelData.urgent
                                    loops: Animation.Infinite
                                    alwaysRunToEnd: true
                                    NumberAnimation {
                                        to: 0.4
                                        duration: 600
                                    }
                                    NumberAnimation {
                                        to: 1.0
                                        duration: 600
                                    }
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: dot.showsLabel
                                width: visible ? Math.min(implicitWidth, Config.workspaces.labelMaxWidth) : 0
                                text: dot.project
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsSm
                                font.weight: dot.isActive ? Font.DemiBold : Font.Normal
                                color: dot.tint

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.durNormal
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: dotMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            onClicked: event => {
                                if (event.button === Qt.MiddleButton)
                                    Compositor.toggleSpecial("magic");
                                else
                                    Compositor.workspace(dot.modelData.id);
                            }
                        }

                        Tooltip {
                            target: dot
                            sideways: root.vertical
                            shown: dot.hovered
                            text: {
                                const ws = dot.modelData.workspace;
                                const name = dot.project === "" ? `Workspace ${dot.modelData.id}` : `Workspace ${dot.modelData.id} · ${dot.project}`;
                                if (!ws)
                                    return `${name} — empty`;
                                const titles = ws.toplevels.values.map(t => t.title).filter(t => !!t);
                                if (titles.length === 0)
                                    return `${name} — empty`;
                                return `${name}\n` + titles.slice(0, 8).join("\n");
                            }
                        }
                    }
                }
            }
        }
    }

    // Scrolling anywhere on the group moves between workspaces.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: event => {
            Compositor.workspaceRelative(event.angleDelta.y > 0 ? -1 : 1);
            event.accepted = true;
        }
    }
}
