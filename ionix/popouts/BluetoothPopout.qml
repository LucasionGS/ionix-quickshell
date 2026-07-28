// Bluetooth devices: connect, pair, trust, forget.

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.config
import qs.components
import qs.services

Popout {
    id: root

    panelWidth: 340

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var paired: Bluetooth.devices.values.filter(d => d.paired || d.bonded)
    readonly property var available: Bluetooth.devices.values.filter(d => !d.paired && !d.bonded && (d.name ?? d.deviceName ?? "") !== "")

    // Discovery drains battery and floods the list; only scan while open.
    onShouldOpenChanged: {
        if (root.adapter && root.adapter.enabled)
            root.adapter.discovering = root.shouldOpen;
    }

    Column {
        width: parent.width
        spacing: Theme.sp3

        // ── Header ──────────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: 26

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Bluetooth"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsBase
                font.weight: Font.DemiBold
                color: Theme.textBright
            }

            Switch {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                enabled: !!root.adapter
                checked: root.adapter?.enabled ?? false
                onToggled: v => {
                    if (root.adapter)
                        root.adapter.enabled = v;
                }
            }
        }

        // No adapter: say so plainly. This is the normal case in a VM.
        Text {
            width: parent.width
            visible: !root.adapter
            horizontalAlignment: Text.AlignHCenter
            text: "No bluetooth adapter found"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsSm
            color: Theme.muted
        }

        Text {
            width: parent.width
            visible: !!root.adapter && !root.adapter.enabled
            horizontalAlignment: Text.AlignHCenter
            text: "Bluetooth is off"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsSm
            color: Theme.muted
        }

        // ── Paired ──────────────────────────────────────────────────────────
        Column {
            width: parent.width
            spacing: 2
            visible: !!root.adapter && root.adapter.enabled && root.paired.length > 0

            Text {
                text: "Paired"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsXs
                font.weight: Font.Bold
                color: Theme.accentLight
                bottomPadding: Theme.sp1
            }

            Repeater {
                model: root.paired

                delegate: ListRow {
                    id: pairedRow
                    required property BluetoothDevice modelData

                    width: parent.width
                    icon: Icons.bluetoothDevice(modelData.icon)
                    title: modelData.name ?? modelData.deviceName ?? modelData.address
                    selected: modelData.connected
                    busy: modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting
                    subtitle: {
                        if (modelData.state === BluetoothDeviceState.Connecting)
                            return "Connecting…";
                        if (!modelData.connected)
                            return "Not connected";
                        return modelData.batteryAvailable ? `Connected  ·  ${Math.round(modelData.battery * 100)}% battery` : "Connected";
                    }

                    onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()
                    onRightClicked: modelData.trusted = !modelData.trusted

                    Row {
                        spacing: Theme.sp2

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: pairedRow.modelData.trusted
                            text: Icons.check
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsSm
                            color: Theme.muted
                        }

                        Switch {
                            anchors.verticalCenter: parent.verticalCenter
                            checked: pairedRow.modelData.connected
                            onToggled: v => v ? pairedRow.modelData.connect() : pairedRow.modelData.disconnect()
                        }
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.divider
            visible: !!root.adapter && root.adapter.enabled && root.paired.length > 0
        }

        // ── Available ───────────────────────────────────────────────────────
        Column {
            width: parent.width
            spacing: 2
            visible: !!root.adapter && root.adapter.enabled

            Item {
                width: parent.width
                height: 18

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Available"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsXs
                    font.weight: Font.Bold
                    color: Theme.accentLight
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.sp2

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.adapter?.discovering ?? false
                        text: "scanning"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsXs
                        color: Theme.muted

                        SequentialAnimation on opacity {
                            running: root.adapter?.discovering ?? false
                            loops: Animation.Infinite
                            NumberAnimation {
                                to: 0.3
                                duration: 700
                            }
                            NumberAnimation {
                                to: 1.0
                                duration: 700
                            }
                        }
                    }

                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalPadding: Theme.sp1
                        fontSize: Theme.fsMd
                        icon: Icons.refresh
                        colour: (root.adapter?.discovering ?? false) ? Theme.accentBright : Theme.muted
                        tooltip: "Toggle scanning"
                        onClicked: {
                            if (root.adapter)
                                root.adapter.discovering = !root.adapter.discovering;
                        }
                    }
                }
            }

            Text {
                width: parent.width
                visible: root.available.length === 0
                horizontalAlignment: Text.AlignHCenter
                text: (root.adapter?.discovering ?? false) ? "Searching for devices…" : "Press refresh to scan"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsSm
                color: Theme.muted
                topPadding: Theme.sp2
                bottomPadding: Theme.sp2
            }

            Repeater {
                model: root.available

                delegate: ListRow {
                    required property BluetoothDevice modelData
                    width: parent.width
                    icon: Icons.bluetoothDevice(modelData.icon)
                    title: modelData.name ?? modelData.deviceName ?? modelData.address
                    subtitle: modelData.pairing ? "Pairing…" : modelData.address
                    busy: modelData.pairing
                    onClicked: modelData.pairing ? modelData.cancelPair() : modelData.pair()
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.divider
        }

        // ── Footer ──────────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: 22

            IconButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                horizontalPadding: Theme.sp2
                icon: Icons.settings
                label: "Bluetooth settings"
                fontSize: Theme.fsMd
                colour: Theme.muted
                onClicked: {
                    Popouts.close();
                    Quickshell.execDetached(["blueman-manager"]);
                }
            }
        }
    }
}
