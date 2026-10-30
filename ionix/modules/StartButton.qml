// A flat logo button opening the start menu, with the power menu on right-click. Hosts
// the same two popouts as Launcher, which it replaces in a theme's module list; the
// difference is the look, a BarTile rather than a glowing IconButton.

import QtQuick
import qs.config
import qs.components
import qs.popouts
import qs.services

Item {
    id: root

    property var bar: null

    implicitWidth: button.thickness + (Config.barVertical ? 0 : 4)
    implicitHeight: button.thickness + (Config.barVertical ? 4 : 0)

    BarTile {
        id: button
        anchors.fill: parent
        active: Popouts.isOpen("start", root.bar?.screen)
        tooltip: "Start"

        onClicked: {
            if (Config.start.enabled)
                Popouts.toggle("start", root.bar?.screen);
            else
                Launch.run(Config.launcher.command);
        }
        onMiddleClicked: Launch.run(Config.launcher.middleCommand)
        onRightClicked: Popouts.toggle("power", root.bar?.screen)

        // launcher.icon in the logo font. A theme imitating another system keeps the
        // Ionix logo here: a vendor's own logo is its trademark.
        Text {
            anchors.centerIn: parent
            text: Config.launcher.icon
            font.family: Theme.fontLogo
            font.pixelSize: 24
            color: Theme.accentLight
            scale: button.pressed ? 0.88 : 1.0

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.durFast
                }
            }
        }
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
