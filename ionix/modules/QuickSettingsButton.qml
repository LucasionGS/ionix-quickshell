// A single button for QuickSettings, for a bar that keeps its status icons as separate
// modules instead of using StatusCluster. Hosts the panel, and whichever detail flyouts
// its chevrons open that no module in the bar hosts already.

import QtQuick
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
    readonly property var battery: UPower.displayDevice

    implicitWidth: button.thickness
    implicitHeight: button.thickness

    BarTile {
        id: button
        anchors.fill: parent
        active: Popouts.isOpen("quicksettings", root.screen)
        tooltip: "Quick Settings"
        onClicked: Popouts.toggle("quicksettings", root.screen)
        onMiddleClicked: Audio.toggleMute()
        onScrolled: direction => Audio.stepVolume(direction)

        Text {
            anchors.centerIn: parent
            text: Icons.tune
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsIcon
            color: Theme.textBright
        }
    }

    // AudioIndicator raises the OSD where it is in the bar; here nothing else would.
    Connections {
        target: Audio
        enabled: !Config.listsModule("AudioIndicator")
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
        hasBattery: !!root.battery?.isLaptopBattery
        charging: root.battery?.state === UPowerDeviceState.Charging || root.battery?.state === UPowerDeviceState.FullyCharged
        wifiDevice: root.wifiDevice
        activeWifi: root.wifiDevice?.networks?.values?.find(n => n.connected) ?? null
        wiredUp: !!root.wiredDevice?.connected
    }

    Loader {
        active: !Config.listsModule("NetworkIndicator")
        sourceComponent: NetworkPopout {
            anchorItem: root
            screenAlign: "right"
            shouldOpen: Popouts.isOpen("network", root.screen)
        }
    }

    Loader {
        active: !Config.listsModule("BluetoothIndicator")
        sourceComponent: BluetoothPopout {
            anchorItem: root
            screenAlign: "right"
            shouldOpen: Popouts.isOpen("bluetooth", root.screen)
        }
    }

    Loader {
        active: !Config.listsModule("AudioIndicator")
        sourceComponent: AudioPopout {
            anchorItem: root
            screenAlign: "right"
            shouldOpen: Popouts.isOpen("audio", root.screen)
        }
    }

    Loader {
        active: !Config.listsModule("HueIndicator")
        sourceComponent: HuePopout {
            anchorItem: root
            screenAlign: "right"
            shouldOpen: Popouts.isOpen("hue", root.screen)
        }
    }
}
