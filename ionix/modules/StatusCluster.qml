// Network, volume and battery as one button, opening QuickSettings. Scroll over it
// for volume. It stands in for NetworkIndicator, AudioIndicator, BluetoothIndicator,
// BatteryIndicator and HueIndicator in a theme's module list, and hosts their detail
// flyouts so QuickSettings' chevrons have something to open.

import QtQuick
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.UPower
import qs.config
import qs.components
import qs.popouts
import qs.services

Item {
    id: root

    property var bar: null

    readonly property var screen: root.bar?.screen
    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: Networking.devices.values.find(d => d.type === DeviceType.Wired) ?? null
    readonly property var activeWifi: root.wifiDevice?.networks?.values?.find(n => n.connected) ?? null
    readonly property bool wiredUp: !!root.wiredDevice?.connected

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: !!root.battery?.isLaptopBattery
    readonly property bool charging: root.battery?.state === UPowerDeviceState.Charging || root.battery?.state === UPowerDeviceState.FullyCharged

    readonly property string networkGlyph: {
        if (root.wiredUp)
            return Icons.ethernet;
        if (!Networking.wifiEnabled)
            return Icons.wifiOff;
        if (root.activeWifi)
            return Icons.wifi(root.activeWifi.signalStrength);
        return Icons.disconnected;
    }

    readonly property bool vertical: Config.barVertical

    implicitWidth: root.vertical ? button.thickness : row.implicitWidth + Theme.sp4 * 2
    implicitHeight: root.vertical ? row.implicitHeight + Theme.sp4 * 2 : button.thickness

    BarTile {
        id: button
        anchors.fill: parent
        active: ["quicksettings", "network", "bluetooth", "audio"].some(name => Popouts.isOpen(name, root.screen))
        tooltip: {
            const lines = [];
            if (root.wiredUp)
                lines.push("Network: Ethernet");
            else if (root.activeWifi)
                lines.push(`Wi-Fi: ${root.activeWifi.name}`);
            lines.push(`Volume: ${Audio.muted ? "muted" : Math.round(Audio.volume * 100) + "%"}`);
            if (root.hasBattery)
                lines.push(`Battery: ${Math.round(root.battery.percentage * 100)}%`);
            return lines.join("\n");
        }

        onClicked: Popouts.toggle("quicksettings", root.screen)
        onMiddleClicked: Audio.toggleMute()
        onScrolled: direction => Audio.stepVolume(direction)

        Grid {
            id: row
            anchors.centerIn: parent
            rows: root.vertical ? 3 : 1
            columns: root.vertical ? 1 : 3
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter
            spacing: Theme.sp3

            Text {
                visible: Config.network.enabled
                text: root.networkGlyph
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsIconLg
                color: Theme.textBright
            }

            Text {
                text: Icons.volume(Audio.volume, Audio.muted, Audio.portType)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsIconLg
                color: Theme.textBright
            }

            Text {
                visible: root.hasBattery
                text: Icons.battery((root.battery?.percentage ?? 0) * 100, root.charging)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsIconLg
                color: Theme.textBright
            }
        }
    }

    // Any volume change, from here, a media key or another app, raises the OSD.
    Connections {
        target: Audio
        function onVolumeChanged() {
            Osd.showVolume(Audio.volume, Audio.muted);
        }
        function onMutedChanged() {
            Osd.showVolume(Audio.volume, Audio.muted);
        }
    }

    QuickSettings {
        anchorItem: root
        shouldOpen: Popouts.isOpen("quicksettings", root.screen)
        batteryDevice: root.battery
        hasBattery: root.hasBattery
        charging: root.charging
        wifiDevice: root.wifiDevice
        activeWifi: root.activeWifi
        wiredUp: root.wiredUp
    }

    NetworkPopout {
        anchorItem: root
        screenAlign: "right"
        shouldOpen: Popouts.isOpen("network", root.screen)
    }

    BluetoothPopout {
        anchorItem: root
        screenAlign: "right"
        shouldOpen: Popouts.isOpen("bluetooth", root.screen)
    }

    AudioPopout {
        anchorItem: root
        screenAlign: "right"
        shouldOpen: Popouts.isOpen("audio", root.screen)
    }

    HuePopout {
        anchorItem: root
        screenAlign: "right"
        shouldOpen: Popouts.isOpen("hue", root.screen)
    }
}
