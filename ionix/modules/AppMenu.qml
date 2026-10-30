// The focused application's name and its menus, along the bar.
//
// A Wayland window publishes no menu of its own, so these hold what the shell can do
// to any window: new windows and desktop actions from its .desktop file, closing,
// minimising, zooming, fullscreen, moving between workspaces. The first title is the
// app's name in bold. With one menu open, moving across the titles switches to the
// next, the way a menu bar does, which is why the bar joins each menu's focus grab.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property var bar: null

    readonly property var toplevel: Hyprland.activeToplevel
    readonly property var entry: root.toplevel ? Windows.entryFor(root.toplevel) : null
    readonly property bool hasWindow: !!root.toplevel && root.toplevel.monitor?.name === root.bar?.screen?.name
    readonly property string appName: {
        if (!root.hasWindow)
            return "Desktop";
        return root.entry?.name ?? Windows.appId(root.toplevel) ?? "Desktop";
    }

    // Which title's menu is up, by index; -1 for none.
    property int openIndex: -1

    function dispatch(legacy, lua) {
        Compositor.dispatch(legacy, lua);
    }

    readonly property var windowsOfApp: {
        if (!root.hasWindow)
            return [];
        const id = Windows.appId(root.toplevel);
        return Windows.toplevels.filter(t => Windows.appId(t) === id);
    }

    readonly property var menus: {
        const has = root.hasWindow;
        const appItems = [
            {
                text: "Minimize",
                hint: "",
                enabled: has,
                trigger: () => Compositor.minimizeActive()
            },
            {
                separator: true
            },
            {
                text: `Quit ${root.appName}`,
                hint: "Super+Q",
                enabled: has,
                trigger: () => {
                    for (const window of root.windowsOfApp)
                        Windows.close(window);
                }
            }
        ];

        const fileItems = [];
        if (root.entry) {
            fileItems.push({
                text: "New Window",
                trigger: () => Apps.launch(root.entry)
            });
            for (const action of Apps.actionItems(root.entry))
                fileItems.push({
                    text: action.text,
                    trigger: action.trigger
                });
            fileItems.push({
                separator: true
            });
        }
        fileItems.push({
            text: "Close Window",
            enabled: has,
            trigger: () => Windows.close(root.toplevel)
        });

        const viewItems = [
            {
                text: "Enter Full Screen",
                hint: "Super+F",
                enabled: has,
                trigger: () => root.dispatch("fullscreen 0", `hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" })`)
            },
            {
                text: "Float Window",
                enabled: has,
                trigger: () => root.dispatch("togglefloating", `hl.dsp.window.float({ action = "toggle" })`)
            },
            {
                text: "Keep on All Desktops",
                hint: "Super+P",
                enabled: has,
                trigger: () => root.dispatch("pin", "hl.dsp.window.pin()")
            }
        ];

        const windowItems = [
            {
                text: "Minimize",
                enabled: has,
                trigger: () => Compositor.minimizeActive()
            },
            {
                text: "Zoom",
                hint: "Super+D",
                enabled: has,
                trigger: () => root.dispatch("fullscreen 1", `hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })`)
            },
            {
                separator: true
            },
            {
                text: "Move to Next Desktop",
                enabled: has,
                trigger: () => root.dispatch("movetoworkspace r+1", `hl.dsp.window.move({ workspace = "r+1", follow = true })`)
            },
            {
                text: "Move to Previous Desktop",
                enabled: has,
                trigger: () => root.dispatch("movetoworkspace r-1", `hl.dsp.window.move({ workspace = "r-1", follow = true })`)
            },
            {
                separator: true
            },
            {
                text: "Task View",
                hint: "Super+Tab",
                trigger: () => TaskView.toggle()
            }
        ];

        return [
            {
                title: root.appName,
                bold: true,
                items: appItems
            },
            {
                title: "File",
                items: fileItems
            },
            {
                title: "View",
                items: viewItems
            },
            {
                title: "Window",
                items: windowItems
            }
        ];
    }

    visible: !Config.barVertical
    implicitWidth: row.implicitWidth
    implicitHeight: Theme.pillHeight

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
            model: root.menus

            delegate: Item {
                id: title
                required property var modelData
                required property int index

                width: label.implicitWidth + Theme.sp5
                height: Theme.pillHeight

                BarTile {
                    anchors.fill: parent
                    active: root.openIndex === title.index
                    onClicked: root.openIndex = root.openIndex === title.index ? -1 : title.index
                    onHoveredChanged: {
                        if (hovered && root.openIndex !== -1)
                            root.openIndex = title.index;
                    }

                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: title.modelData.title
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsBase
                        font.weight: title.modelData.bold ? Font.Bold : Font.Normal
                        color: Theme.textBright
                    }
                }

                ContextMenu {
                    anchorItem: title
                    shouldOpen: root.openIndex === title.index
                    model: title.modelData.items
                    minWidth: 220
                    grabWindows: root.bar ? [root.bar] : []
                    onDismissRequested: {
                        if (root.openIndex === title.index)
                            root.openIndex = -1;
                    }
                }
            }
        }
    }
}
