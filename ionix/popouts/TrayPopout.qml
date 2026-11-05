// The tray items, in a grid above the taskbar's chevron.

import QtQuick
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

Popout {
    id: root

    readonly property var items: SystemTray.items.values
    readonly property int cell: 40
    readonly property int columns: Math.min(4, Math.max(1, root.items.length))
    // The entry whose menu is open, so there is only ever one, and the panel knows
    // to leave the focus grab to it.
    property Item menuEntry: null

    childGrab: root.menuEntry !== null
    // Closed from outside (IPC, another popout) with a menu up: it must not come
    // back with the panel next time.
    onVisibleChanged: {
        if (!root.visible)
            root.menuEntry = null;
    }

    panelWidth: root.columns * root.cell + Theme.sp2 * 2
    padding: Theme.sp2

    Grid {
        columns: root.columns

        Repeater {
            model: root.items

            delegate: Item {
                id: entry
                required property SystemTrayItem modelData
                readonly property bool menuOpen: root.menuEntry === entry

                width: root.cell
                height: root.cell

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.rSm
                    color: mouse.pressed ? Theme.subtlePressed : (mouse.containsMouse || entry.menuOpen ? Theme.subtleHover : "transparent")
                }

                IconImage {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    source: entry.modelData.icon
                    asynchronous: true
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onClicked: event => {
                        const item = entry.modelData;
                        if (event.button === Qt.MiddleButton) {
                            item.secondaryActivate();
                        }
                        else if (event.button === Qt.RightButton || item.onlyMenu) {
                            if (item.hasMenu)
                                root.menuEntry = entry.menuOpen ? null : entry;
                        }
                        else {
                            item.activate();
                            Popouts.close();
                        }
                    }
                    onWheel: event => {
                        entry.modelData.scroll(event.angleDelta.y, false);
                        event.accepted = true;
                    }
                }

                TrayMenu {
                    menuHandle: entry.modelData.menu
                    anchorItem: entry
                    shouldOpen: entry.menuOpen && root.shouldOpen
                    grabWindows: [root]
                    onFinished: Popouts.close()
                    onDismissRequested: {
                        if (root.menuEntry === entry)
                            root.menuEntry = null;
                    }
                }

                Tooltip {
                    target: entry
                    shown: mouse.containsMouse && !entry.menuOpen
                    text: entry.modelData.tooltipTitle !== "" ? entry.modelData.tooltipTitle : entry.modelData.title
                }
            }
        }
    }
}
