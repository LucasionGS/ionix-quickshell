// System tray.
//
// Left click activates, middle click runs the secondary action, right click opens
// the item's DBus menu — drawn by TrayMenu in the shell's own theme rather than by
// QsMenuAnchor's unstyled platform menu.

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.config
import qs.components

Item {
    id: root

    property var bar: null

    readonly property var items: SystemTray.items.values

    readonly property bool vertical: Config.barVertical

    visible: root.items.length > 0
    implicitWidth: root.vertical ? Theme.pillHeight : layout.implicitWidth + Theme.sp2
    implicitHeight: root.vertical ? layout.implicitHeight + Theme.sp2 : Theme.pillHeight

    Grid {
        id: layout
        anchors.centerIn: parent
        rows: root.vertical ? Math.max(1, root.items.length) : 1
        columns: root.vertical ? 1 : Math.max(1, root.items.length)
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
        spacing: Theme.sp2

        Repeater {
            model: root.items

            delegate: Item {
                id: entry
                required property SystemTrayItem modelData

                property bool menuOpen: false

                width: 26
                height: 26

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.rSm
                    color: (itemMouse.containsMouse || entry.menuOpen) ? Theme.alpha(Theme.accentLight, 0.14) : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durNormal
                        }
                    }
                }

                IconImage {
                    id: icon
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    source: entry.modelData.icon
                    asynchronous: true
                    scale: itemMouse.containsMouse ? 1.15 : 1.0

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.durFast
                            easing.type: Theme.easeOvershoot
                        }
                    }
                }

                MouseArea {
                    id: itemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor

                    onClicked: event => {
                        const item = entry.modelData;
                        if (event.button === Qt.MiddleButton) {
                            item.secondaryActivate();
                            return;
                        }
                        // Items that declare onlyMenu have no meaningful activate
                        // action, so a left click should open the menu instead.
                        if (event.button === Qt.RightButton || item.onlyMenu) {
                            if (item.hasMenu)
                                entry.menuOpen = !entry.menuOpen;
                        } else {
                            item.activate();
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
                    shouldOpen: entry.menuOpen
                    onDismissRequested: entry.menuOpen = false
                }

                Tooltip {
                    target: entry
                    sideways: root.vertical
                    // The menu already labels the item, and the tooltip would
                    // otherwise sit on top of it.
                    shown: itemMouse.containsMouse && !entry.menuOpen
                    text: entry.modelData.tooltipTitle !== "" ? entry.modelData.tooltipTitle : entry.modelData.title
                }
            }
        }
    }
}
