// A chevron hiding the system tray: icons live in a small flyout instead of on the
// bar. Tray is the alternative that keeps them all on show.

import QtQuick
import Quickshell.Services.SystemTray
import qs.config
import qs.popouts
import qs.services

Item {
    id: root

    property var bar: null

    readonly property bool popoutOpen: Popouts.isOpen("tray", root.bar?.screen)

    visible: SystemTray.items.values.length > 0
    implicitWidth: Config.barVertical ? button.thickness : 30
    implicitHeight: Config.barVertical ? 30 : button.thickness

    BarTile {
        id: button
        anchors.fill: parent
        active: root.popoutOpen
        tooltip: "Show hidden icons"
        onClicked: Popouts.toggle("tray", root.bar?.screen)

        Text {
            anchors.centerIn: parent
            // Pointing the way the flyout opens.
            text: {
                if (Config.bar.position === "left")
                    return Icons.chevronRight;
                if (Config.bar.position === "right")
                    return Icons.chevronLeft;
                return Config.bar.position === "top" ? Icons.chevronDown : Icons.chevronUp;
            }
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsIcon
            color: Theme.textBright
        }
    }

    TrayPopout {
        anchorItem: root
        shouldOpen: root.popoutOpen
    }
}
