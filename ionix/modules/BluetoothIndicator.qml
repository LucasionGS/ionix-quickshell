// Bluetooth status, with a count badge when more than one device is connected.

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.config
import qs.components
import qs.popouts
import qs.services

Item {
    id: root

    property var bar: null
    readonly property bool popoutOpen: Popouts.isOpen("bluetooth", root.bar?.screen)

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool enabled: !!root.adapter?.enabled
    readonly property var connected: Bluetooth.devices.values.filter(d => d.connected)

    // No adapter at all (desktop without a dongle, or a VM) — take up no space.
    visible: Config.bluetooth.enabled && !!root.adapter
    implicitWidth: visible ? button.implicitWidth : 0
    implicitHeight: Theme.pillHeight

    IconButton {
        id: button
        anchors.fill: parent
        active: root.popoutOpen
        icon: Icons.bluetooth(root.enabled, root.connected.length)
        colour: {
            if (!root.enabled)
                return Theme.border;
            return root.connected.length > 0 ? Theme.accentBright : Theme.cyan;
        }

        tooltip: {
            if (!root.enabled)
                return "Bluetooth off";
            if (root.connected.length === 0)
                return "Bluetooth on  ·  nothing connected";
            return root.connected.map(d => {
                const battery = d.batteryAvailable ? `  ${Math.round(d.battery * 100)}%` : "";
                return `${d.name ?? d.deviceName}${battery}`;
            }).join("\n");
        }

        onClicked: Popouts.toggle("bluetooth", root.bar?.screen)
        onMiddleClicked: {
            if (root.adapter)
                root.adapter.enabled = !root.adapter.enabled;
        }
        onRightClicked: Quickshell.execDetached(["blueman-manager"])

        // Count badge, only once it's ambiguous which device is meant.
        Rectangle {
            visible: root.connected.length > 1
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 3
            anchors.topMargin: 6
            width: 12
            height: 12
            radius: 6
            color: Theme.accentBright
            border.width: 1
            border.color: Theme.bgDeep

            Text {
                anchors.centerIn: parent
                text: root.connected.length
                font.family: Theme.fontFamily
                font.pixelSize: 8
                font.weight: Font.Bold
                color: Theme.bgDeep
            }
        }
    }

    BluetoothPopout {
        anchorItem: root
        shouldOpen: root.popoutOpen
    }
}
