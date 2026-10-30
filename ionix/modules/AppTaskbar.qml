// Pinned apps and running windows in one strip, one button per application rather
// than per window. Taskbar is the plain alternative: running windows only, one each.
// The pip under a button says which state it is in: none for closed, a short grey one
// for running, a longer accent one for the app holding focus.
//
// A click on a closed app starts it, on an open one raises it, and on the app
// already focused moves on to its next window. Hovering shows a live thumbnail
// per window above the button.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property var bar: null

    // The apps to draw; see AppGroups.
    readonly property var apps: AppGroups.forScreen(root.bar?.screen)

    // Which button's preview is up. Held in one place so moving from one button to
    // the next swaps the preview rather than stacking two.
    property string previewKey: ""

    readonly property bool vertical: Config.barVertical
    readonly property int lane: Config.bar.height - 8

    visible: Config.taskbar.enabled
    implicitWidth: root.vertical ? root.lane : row.implicitWidth
    implicitHeight: root.vertical ? row.implicitHeight : root.lane

    // Grid rather than Row: the one positioner that can run either way.
    Grid {
        id: row
        anchors.centerIn: parent
        rows: root.vertical ? Math.max(1, root.apps.length) : 1
        columns: root.vertical ? 1 : Math.max(1, root.apps.length)
        spacing: 2

        Repeater {
            model: root.apps

            delegate: Item {
                id: button
                required property var modelData

                readonly property var group: button.modelData
                readonly property bool running: button.group.windows.length > 0
                readonly property bool focused: button.group.windows.some(w => w.activated)
                property bool menuOpen: false

                width: root.vertical ? root.lane : 44
                height: root.vertical ? 44 : root.lane

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.rSm
                    color: {
                        if (mouse.pressed)
                            return Theme.subtlePressed;
                        if (mouse.containsMouse || button.menuOpen || button.focused)
                            return Theme.subtleHover;
                        return "transparent";
                    }
                    border.width: button.focused ? 1 : 0
                    border.color: Theme.controlStroke

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durFast
                        }
                    }
                }

                // First letter when the app has no themed icon, so the bar has no holes.
                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -1
                    visible: button.group.iconSource === ""
                    text: button.group.title.charAt(0).toUpperCase()
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsXl
                    font.weight: Font.DemiBold
                    color: Theme.textBright
                }

                IconImage {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -1
                    visible: button.group.iconSource !== ""
                    width: 24
                    height: 24
                    source: button.group.iconSource
                    asynchronous: true
                    scale: mouse.pressed ? 0.86 : 1.0

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.durFast
                        }
                    }
                }

                // The running pip, on the edge facing the desktop. Positioned with
                // x/y: anchors would have to swap axes as the bar turns.
                Rectangle {
                    readonly property int length: button.focused ? 16 : (button.running ? 6 : 0)
                    readonly property bool onLeft: Config.bar.position === "right"
                    x: root.vertical ? (onLeft ? 1 : parent.width - width - 1) : (parent.width - width) / 2
                    y: root.vertical ? (parent.height - height) / 2 : parent.height - height - 1
                    width: root.vertical ? 3 : length
                    height: root.vertical ? length : 3
                    radius: 1.5
                    visible: button.running
                    color: button.focused ? Theme.accentBright : Theme.muted

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
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                    onContainsMouseChanged: {
                        if (containsMouse && button.running) {
                            previewDelay.restart();
                        }
                        else {
                            previewDelay.stop();
                            previewLinger.restart();
                        }
                    }

                    onClicked: event => {
                        root.previewKey = "";
                        previewDelay.stop();
                        if (event.button === Qt.RightButton) {
                            // Model first: the menu measures itself as it opens.
                            menu.model = AppGroups.menuFor(button.group, "taskbar");
                            button.menuOpen = !button.menuOpen;
                        }
                        else if (event.button === Qt.MiddleButton) {
                            AppGroups.launch(button.group);
                        }
                        else {
                            AppGroups.activate(button.group);
                        }
                    }
                }

                Timer {
                    id: previewDelay
                    interval: 400
                    onTriggered: root.previewKey = button.group.key
                }

                ContextMenu {
                    id: menu
                    anchorItem: button
                    shouldOpen: button.menuOpen
                    onDismissRequested: button.menuOpen = false
                }

                Tooltip {
                    target: button
                    sideways: root.vertical
                    shown: mouse.containsMouse && !button.menuOpen && !button.running
                    text: button.group.title
                }

                TaskPreview {
                    anchorItem: button
                    shouldOpen: root.previewKey === button.group.key && button.running && !button.menuOpen
                    windows: button.group.windows
                    onEntered: previewLinger.stop()
                    onExited: previewLinger.restart()
                    onDismissed: root.previewKey = ""
                }
            }
        }
    }

    // Long enough to cross the gap between a button and its preview.
    Timer {
        id: previewLinger
        interval: 280
        onTriggered: root.previewKey = ""
    }
}
