// Workspace dots for this monitor, with one accent blob sliding to the active one.

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

    implicitWidth: pill.implicitWidth
    implicitHeight: Theme.pillHeight

    Pill {
        id: pill
        anchors.fill: parent
        padding: Theme.sp2

        Item {
            implicitWidth: dotsRow.width
            width: dotsRow.width
            height: Theme.pillHeight - 8
            anchors.verticalCenter: parent.verticalCenter

            // Single blob rather than a border per item: one thing to animate, and
            // it reads as the indicator moving rather than two things blinking.
            SlidingIndicator {
                height: parent.height
                anchors.verticalCenter: parent.verticalCenter
                active: root.activeIndex >= 0
                targetX: {
                    if (root.activeIndex < 0)
                        return 0;
                    const item = dots.itemAt(root.activeIndex);
                    return item ? item.x : 0;
                }
                targetWidth: {
                    if (root.activeIndex < 0)
                        return 0;
                    const item = dots.itemAt(root.activeIndex);
                    return item ? item.width : 0;
                }
            }

            Row {
                id: dotsRow
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

                        width: isActive ? 34 : (modelData.occupied ? 26 : 20)
                        height: Theme.pillHeight - 8

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.durSlide
                                easing.type: Theme.easeStandard
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: {
                                if (dot.modelData.urgent)
                                    return Icons.wsUrgent;
                                if (dot.isActive)
                                    return Icons.wsActive;
                                return dot.modelData.occupied ? Icons.wsOccupied : Icons.wsEmpty;
                            }
                            font.family: Theme.fontFamily
                            font.pixelSize: dot.isActive ? Theme.fsMd : Theme.fsSm
                            color: {
                                if (dot.modelData.urgent)
                                    return Theme.orange;
                                if (dot.isActive)
                                    return Theme.textBright;
                                if (dot.hovered)
                                    return Theme.accentLight;
                                return dot.modelData.occupied ? Theme.text : Theme.border;
                            }
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
                            shown: dot.hovered
                            text: {
                                const ws = dot.modelData.workspace;
                                if (!ws)
                                    return `Workspace ${dot.modelData.id} — empty`;
                                const titles = ws.toplevels.values.map(t => t.title).filter(t => !!t);
                                if (titles.length === 0)
                                    return `Workspace ${dot.modelData.id} — empty`;
                                return `Workspace ${dot.modelData.id}\n` + titles.slice(0, 8).join("\n");
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
