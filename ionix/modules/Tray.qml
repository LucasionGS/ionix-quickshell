// System tray.
//
// Right-click opens the item's DBus menu through QsMenuAnchor, which renders it
// as a native-feeling menu; we don't try to restyle it, because DBusMenu content
// is arbitrary and a half-styled menu looks worse than an unstyled one.

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

    visible: root.items.length > 0
    implicitWidth: visible ? layout.implicitWidth + Theme.sp2 : 0
    implicitHeight: Theme.pillHeight

    Row {
        id: layout
        anchors.centerIn: parent
        spacing: Theme.sp2

        Repeater {
            model: root.items

            delegate: Item {
                id: entry
                required property SystemTrayItem modelData

                width: 26
                height: 26

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.rSm
                    color: itemMouse.containsMouse ? Theme.alpha(Theme.accentLight, 0.14) : "transparent"

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
                                menu.open();
                        } else {
                            item.activate();
                        }
                    }

                    onWheel: event => {
                        entry.modelData.scroll(event.angleDelta.y, false);
                        event.accepted = true;
                    }
                }

                QsMenuAnchor {
                    id: menu
                    menu: entry.modelData.menu
                    anchor.item: entry
                    anchor.gravity: Edges.Bottom
                    anchor.edges: Edges.Bottom
                }

                Tooltip {
                    target: entry
                    shown: itemMouse.containsMouse
                    text: entry.modelData.tooltipTitle !== "" ? entry.modelData.tooltipTitle : entry.modelData.title
                }
            }
        }
    }
}
