// Window list for this monitor, across all of its workspaces.
//
// Acts on the wlr-foreign-toplevel handle rather than dispatching to Hyprland, and
// reports each button's rectangle back to the compositor with setRectangle() so
// minimise animations fly toward the right icon.

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property var bar: null
    readonly property var windows: Windows.forScreen(root.bar?.screen)

    visible: Config.taskbar.enabled && root.windows.length > 0
    implicitWidth: visible ? Math.min(Config.taskbar.maxWidth, layout.implicitWidth + Theme.sp3) : 0
    implicitHeight: Theme.pillHeight

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Theme.durSlide
            easing.type: Theme.easeStandard
        }
    }

    Pill {
        anchors.fill: parent
        padding: Theme.sp2

        Item {
            width: Math.min(Config.taskbar.maxWidth - Theme.sp4, layout.implicitWidth)
            height: Theme.pillHeight - 8
            anchors.verticalCenter: parent.verticalCenter

            Flickable {
                id: flick
                anchors.fill: parent
                contentWidth: layout.implicitWidth
                contentHeight: height
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Row {
                    id: layout
                    height: parent.height
                    spacing: Theme.sp1

                    Repeater {
                        model: root.windows

                        delegate: Item {
                            id: entry
                            required property var modelData

                            readonly property bool isActive: modelData.activated
                            readonly property bool hovered: entryMouse.containsMouse
                            property bool menuOpen: false
                            // An open menu keeps its button lit, so it stays obvious
                            // which window the menu belongs to once the pointer has
                            // moved off the button and onto the menu itself.
                            readonly property bool highlighted: entry.hovered || entry.menuOpen

                            width: Config.taskbar.iconSize + Theme.sp4
                            height: layout.height

                            readonly property string iconName: Windows.iconFor(entry.modelData)

                            // Placeholder for windows with no themed icon: the app's
                            // first letter, which is still identifiable at a glance.
                            Rectangle {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -1
                                visible: entry.iconName === ""
                                width: Config.taskbar.iconSize
                                height: Config.taskbar.iconSize
                                radius: Theme.rSm
                                color: Theme.alpha(Theme.accentBright, 0.18)
                                opacity: icon.opacity

                                Text {
                                    anchors.centerIn: parent
                                    text: (Windows.appId(entry.modelData) || "?").charAt(0).toUpperCase()
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsMd
                                    font.weight: Font.Bold
                                    color: Theme.accentLight
                                }
                            }

                            IconImage {
                                id: icon
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -1
                                visible: entry.iconName !== ""
                                width: Config.taskbar.iconSize
                                height: Config.taskbar.iconSize
                                source: entry.iconName === "" ? "" : Quickshell.iconPath(entry.iconName)
                                asynchronous: true
                                opacity: entry.isActive ? 1.0 : (entry.highlighted ? 0.95 : 0.55)
                                scale: entry.highlighted ? 1.12 : 1.0

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Theme.durNormal
                                    }
                                }
                                Behavior on scale {
                                    NumberAnimation {
                                        duration: Theme.durFast
                                        easing.type: Theme.easeOvershoot
                                    }
                                }
                            }

                            // Tell the compositor where this window's button is, so
                            // minimise/restore animates toward it.
                            onXChanged: entry.reportRect()
                            Component.onCompleted: entry.reportRect()

                            function reportRect() {
                                const wl = entry.modelData?.wayland;
                                if (wl && root.bar)
                                    wl.setRectangle(root.bar, Qt.rect(entry.x, entry.y, entry.width, entry.height));
                            }

                            MouseArea {
                                id: entryMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: event => {
                                    if (event.button === Qt.RightButton) {
                                        if (entry.menuOpen) {
                                            entry.menuOpen = false;
                                            return;
                                        }
                                        // Assigned rather than bound: menuFor() builds
                                        // a fresh array every call, so a binding would
                                        // rebuild every row on any unrelated change.
                                        menu.model = Windows.menuFor(entry.modelData);
                                        entry.menuOpen = true;
                                    } else if (event.button === Qt.MiddleButton) {
                                        Windows.close(entry.modelData);
                                    } else {
                                        Windows.activate(entry.modelData);
                                    }
                                }
                            }

                            ContextMenu {
                                id: menu
                                anchorItem: entry
                                shouldOpen: entry.menuOpen
                                headerText: entry.modelData.title ?? Windows.appId(entry.modelData)
                                headerIcon: entry.iconName
                                onDismissRequested: entry.menuOpen = false
                            }

                            Tooltip {
                                target: entry
                                shown: entry.hovered && !entry.menuOpen
                                text: entry.modelData.title ?? Windows.appId(entry.modelData)
                            }
                        }
                    }
                }
            }

            // Sliding underline under the focused window.
            SlidingIndicator {
                height: 2
                y: parent.height - 2
                colourStart: Theme.accentBright
                colourEnd: Theme.accentBright
                active: root.activeIndex >= 0
                targetX: {
                    const i = root.activeIndex;
                    if (i < 0)
                        return 0;
                    return i * (Config.taskbar.iconSize + Theme.sp4 + Theme.sp1) + Theme.sp2 - flick.contentX;
                }
                targetWidth: root.activeIndex >= 0 ? Config.taskbar.iconSize : 0
            }

            // Edge fades so a scrolled list doesn't just get cut off.
            Rectangle {
                anchors.left: parent.left
                width: 12
                height: parent.height
                visible: flick.contentX > 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0.0
                        color: Theme.bgDeep
                    }
                    GradientStop {
                        position: 1.0
                        color: "transparent"
                    }
                }
            }

            Rectangle {
                anchors.right: parent.right
                width: 12
                height: parent.height
                visible: flick.contentX < flick.contentWidth - flick.width - 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0.0
                        color: "transparent"
                    }
                    GradientStop {
                        position: 1.0
                        color: Theme.bgDeep
                    }
                }
            }
        }
    }

    readonly property int activeIndex: root.windows.findIndex(w => w.activated)
}
