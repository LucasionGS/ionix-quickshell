// Wi-Fi / ethernet status.

import QtQuick
import Quickshell
import Quickshell.Networking
import qs.config
import qs.components
import qs.popouts
import qs.services

Item {
    id: root

    property var bar: null
    readonly property bool popoutOpen: Popouts.isOpen("network", root.bar?.screen)

    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: Networking.devices.values.find(d => d.type === DeviceType.Wired) ?? null

    readonly property var activeWifi: root.wifiDevice?.networks?.values?.find(n => n.connected) ?? null
    readonly property bool wiredUp: !!root.wiredDevice?.connected
    readonly property bool connecting: root.wifiDevice?.state === ConnectionState.Connecting || root.wiredDevice?.state === ConnectionState.Connecting

    visible: Config.network.enabled
    implicitWidth: visible ? button.implicitWidth : 0
    implicitHeight: Theme.pillHeight

    IconButton {
        id: button
        anchors.fill: parent
        active: root.popoutOpen

        icon: {
            if (root.wiredUp)
                return Icons.ethernet;
            if (!Networking.wifiEnabled)
                return Icons.wifiOff;
            if (root.activeWifi)
                return Icons.wifi(root.activeWifi.signalStrength);
            return Icons.disconnected;
        }

        colour: {
            if (root.wiredUp || root.activeWifi)
                return Theme.accentLight;
            return Theme.muted;
        }

        tooltip: {
            if (root.wiredUp)
                return `Ethernet  ·  ${root.wiredDevice.address ?? "connected"}`;
            if (!Networking.wifiEnabled)
                return "Wi-Fi off";
            if (root.activeWifi)
                return `${root.activeWifi.name}  ·  ${Math.round(root.activeWifi.signalStrength * 100)}%\n${root.wifiDevice?.address ?? ""}`;
            return "Disconnected";
        }

        onClicked: Popouts.toggle("network", root.bar?.screen)
        onRightClicked: Quickshell.execDetached(["nm-connection-editor"])

        // Pulse while a connection is being established.
        SequentialAnimation on opacity {
            running: root.connecting
            loops: Animation.Infinite
            alwaysRunToEnd: true
            NumberAnimation {
                to: 0.4
                duration: 600
            }
            NumberAnimation {
                to: 1.0
                duration: 600
            }
        }
    }

    NetworkPopout {
        anchorItem: root
        shouldOpen: root.popoutOpen
    }
}
