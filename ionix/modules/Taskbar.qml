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

    readonly property bool vertical: Config.barVertical
    // Short axis of the strip; the long axis is what grows with the window list.
    readonly property int lane: Theme.pillHeight - 8
    // Pitch of one button along the long axis, which the indicator below steps by.
    readonly property int cell: Config.taskbar.iconSize + Theme.sp4
    // maxWidth is the cap on the growing axis, so it caps the height of a
    // vertical taskbar. Keeping the key name means no theme has to be rewritten.
    readonly property int maxExtent: Config.taskbar.maxWidth
    readonly property real listExtent: root.vertical ? layout.implicitHeight : layout.implicitWidth

    visible: Config.taskbar.enabled && root.windows.length > 0
    implicitWidth: root.vertical ? Theme.pillHeight : Math.min(root.maxExtent, root.listExtent + Theme.sp3)
    implicitHeight: root.vertical ? Math.min(root.maxExtent, root.listExtent + Theme.sp3) : Theme.pillHeight

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Theme.durSlide
            easing.type: Theme.easeStandard
        }
    }
    Behavior on implicitHeight {
        NumberAnimation {
            duration: Theme.durSlide
            easing.type: Theme.easeStandard
        }
    }

    Pill {
        anchors.fill: parent
        vertical: root.vertical
        padding: Theme.sp2

        Item {
            width: root.vertical ? root.lane : Math.min(root.maxExtent - Theme.sp4, root.listExtent)
            height: root.vertical ? Math.min(root.maxExtent - Theme.sp4, root.listExtent) : root.lane

            Flickable {
                id: flick
                anchors.fill: parent
                contentWidth: root.vertical ? width : layout.implicitWidth
                contentHeight: root.vertical ? layout.implicitHeight : height
                flickableDirection: root.vertical ? Flickable.VerticalFlick : Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Grid {
                    id: layout
                    rows: root.vertical ? Math.max(1, root.windows.length) : 1
                    columns: root.vertical ? 1 : Math.max(1, root.windows.length)
                    horizontalItemAlignment: Grid.AlignHCenter
                    verticalItemAlignment: Grid.AlignVCenter
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

                            width: root.vertical ? root.lane : root.cell
                            height: root.vertical ? root.cell : root.lane

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
                            onYChanged: entry.reportRect()
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
                                sideways: root.vertical
                                shown: entry.hovered && !entry.menuOpen
                                text: entry.modelData.title ?? Windows.appId(entry.modelData)
                            }
                        }
                    }
                }
            }

            // Sliding rule beside the focused window — under it on a horizontal
            // bar, along its inner edge on a vertical one. Positioned from the
            // index rather than from the delegate, because the delegate's own
            // coordinates are inside the Flickable's moving content item.
            SlidingIndicator {
                vertical: root.vertical
                colourStart: Theme.accentBright
                colourEnd: Theme.accentBright
                active: root.activeIndex >= 0
                readonly property real offset: root.activeIndex < 0 ? 0 : root.activeIndex * (root.cell + Theme.sp1) + Theme.sp2
                targetX: root.vertical ? parent.width - 2 : offset - flick.contentX
                targetY: root.vertical ? offset - flick.contentY : parent.height - 2
                targetWidth: root.vertical ? 2 : (root.activeIndex >= 0 ? Config.taskbar.iconSize : 0)
                targetHeight: root.vertical ? (root.activeIndex >= 0 ? Config.taskbar.iconSize : 0) : 2
            }

            // Edge fades so a scrolled list doesn't just get cut off.
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                width: root.vertical ? parent.width : 12
                height: root.vertical ? 12 : parent.height
                visible: (root.vertical ? flick.contentY : flick.contentX) > 2
                gradient: Gradient {
                    orientation: root.vertical ? Gradient.Vertical : Gradient.Horizontal
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
                anchors.bottom: parent.bottom
                width: root.vertical ? parent.width : 12
                height: root.vertical ? 12 : parent.height
                visible: root.vertical ? flick.contentY < flick.contentHeight - flick.height - 2 : flick.contentX < flick.contentWidth - flick.width - 2
                gradient: Gradient {
                    orientation: root.vertical ? Gradient.Vertical : Gradient.Horizontal
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
