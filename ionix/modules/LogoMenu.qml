// The logo as a menu: settings, power and session, in one drop-down. Stands in for
// Launcher or StartButton in a theme's module list, and hosts the two popouts those
// would, so Settings and the battery's power panel stay reachable.

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.popouts
import qs.services

Item {
    id: root

    property var bar: null

    property bool menuOpen: false

    implicitWidth: button.thickness + Theme.sp3
    implicitHeight: button.thickness

    readonly property var items: [
        {
            text: "About This Computer",
            trigger: () => Launch.run(["ionterm", "-e", "sh", "-c", "fastfetch; read -r -n 1 -s"])
        },
        {
            separator: true
        },
        {
            text: "Settings…",
            trigger: () => {
                Popouts.startView = "settings";
                Popouts.open("start", root.bar?.screen);
            }
        },
        {
            text: "All Apps",
            hint: "Super",
            trigger: () => AppGrid.toggle()
        },
        {
            text: "Keyboard Shortcuts",
            hint: "Super+F1",
            trigger: () => Shortcuts.toggle()
        },
        {
            separator: true
        },
        {
            text: "Sleep",
            trigger: () => Launch.run(Config.power.suspend)
        },
        {
            text: "Restart…",
            trigger: () => Launch.run(Config.power.reboot)
        },
        {
            text: "Shut Down…",
            trigger: () => Launch.run(Config.power.shutdown)
        },
        {
            separator: true
        },
        {
            text: "Lock Screen",
            hint: "Super+L",
            trigger: () => Launch.run(Config.power.lock)
        },
        {
            text: "Log Out…",
            trigger: () => Launch.run(Config.power.logout)
        }
    ]

    BarTile {
        id: button
        anchors.fill: parent
        active: root.menuOpen
        onClicked: root.menuOpen = !root.menuOpen
        onRightClicked: Popouts.toggle("power", root.bar?.screen)

        // launcher.icon in the logo font: this is Ionix's mark, in every theme.
        Text {
            anchors.centerIn: parent
            text: Config.launcher.icon
            font.family: Theme.fontLogo
            font.pixelSize: Theme.fsIconLg
            color: Theme.textBright
        }
    }

    ContextMenu {
        anchorItem: button
        shouldOpen: root.menuOpen
        model: root.items
        minWidth: 230
        onDismissRequested: root.menuOpen = false
    }

    StartPopout {
        anchorItem: root
        shouldOpen: Popouts.isOpen("start", root.bar?.screen)
    }

    PowerPopout {
        anchorItem: root
        shouldOpen: Popouts.isOpen("power", root.bar?.screen)
    }
}
