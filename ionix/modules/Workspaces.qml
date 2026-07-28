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

    // Hyprland only reports workspaces that exist. Pad the list out to
    // `persistent` so the bar doesn't reflow every time a workspace empties.
    readonly property var items: {
        const live = Hyprland.workspaces.values.filter(w => {
            if (w.id < 0)
                return false;      // special workspaces
            if (Config.workspaces.activeOnly && (!root.monitor || w.monitor !== root.monitor))
                return false;
            return true;
        });

        const byId = {};
        for (const w of live)
            byId[w.id] = w;

        const result = [];
        const persistent = Config.workspaces.persistent;
        const maxId = live.reduce((m, w) => Math.max(m, w.id), 0);

        for (let i = 1; i <= Math.max(persistent, maxId); i++) {
            const w = byId[i];
            if (w)
                result.push({
                    id: i,
                    workspace: w,
                    occupied: w.toplevels.values.length > 0,
                    active: w.active,
                    urgent: w.urgent
                });
            else if (i <= persistent && Config.workspaces.showEmpty)
                result.push({
                    id: i,
                    workspace: null,
                    occupied: false,
                    active: false,
                    urgent: false
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
