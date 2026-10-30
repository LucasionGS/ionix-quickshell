// Quick Settings: toggle tiles, brightness and volume sliders, and a footer strip with
// the battery and a way to Settings. Opened by StatusCluster.
//
// Each tile with something behind it is split: the left part toggles, the chevron
// opens the existing detail popout, which takes this one's place because Popouts only
// ever holds one open panel.

import QtQuick
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.UPower
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

Popout {
    id: root

    property var batteryDevice: null
    property bool hasBattery: false
    property bool charging: false
    property var wifiDevice: null
    property var activeWifi: null
    property bool wiredUp: false

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var connectedDevices: Bluetooth.devices.values.filter(d => d.connected)
    // Airplane mode: Wi-Fi and Bluetooth both off.
    readonly property bool airplane: !Networking.wifiEnabled && !(root.adapter?.enabled ?? false)
    readonly property int tileWidth: Math.floor((root.panelWidth - root.padding * 2 - Theme.sp2 * 2) / 3)

    panelWidth: 360
    padding: Theme.sp5
    screenAlign: "right"

    Column {
        width: parent.width
        spacing: Theme.sp4

        // ── Now playing ─────────────────────────────────────────────────────
        Rectangle {
            width: parent.width
            height: Player.active ? 72 : 0
            visible: Player.active
            radius: Theme.rSm
            color: Theme.controlFill
            border.width: 1
            border.color: Theme.controlStroke

            ClippingRectangle {
                id: art
                x: Theme.sp3
                anchors.verticalCenter: parent.verticalCenter
                width: 48
                height: 48
                radius: Theme.rSm
                color: Theme.bgCard

                Image {
                    anchors.fill: parent
                    source: Player.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(96, 96)
                }
            }

            Column {
                anchors.left: art.right
                anchors.leftMargin: Theme.sp3
                anchors.right: controls.left
                anchors.rightMargin: Theme.sp2
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    width: parent.width
                    text: Player.title
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsBase
                    font.weight: Font.DemiBold
                    color: Theme.textBright
                }

                Text {
                    width: parent.width
                    text: Player.artist !== "" ? Player.artist : Player.identity
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsSm
                    color: Theme.muted
                }
            }

            Row {
                id: controls
                anchors.right: parent.right
                anchors.rightMargin: Theme.sp2
                anchors.verticalCenter: parent.verticalCenter

                IconButton {
                    icon: Icons.prev
                    onClicked: Player.previous()
                }
                IconButton {
                    icon: Player.playing ? Icons.pause : Icons.play
                    onClicked: Player.toggle()
                }
                IconButton {
                    icon: Icons.next
                    onClicked: Player.next()
                }
            }
        }

        // ── Tiles ───────────────────────────────────────────────────────────
        Grid {
            columns: 3
            columnSpacing: Theme.sp2
            rowSpacing: Theme.sp3

            Tile {
                glyph: root.wiredUp ? Icons.ethernet : (root.activeWifi ? Icons.wifi(root.activeWifi.signalStrength) : (Networking.wifiEnabled ? Icons.wifi(1) : Icons.wifiOff))
                label: root.wiredUp ? "Ethernet" : (root.activeWifi?.name ?? "Wi-Fi")
                on: root.wiredUp || Networking.wifiEnabled
                hasDetail: true
                onToggled: {
                    if (root.wifiDevice)
                        Networking.wifiEnabled = !Networking.wifiEnabled;
                }
                onDetail: Popouts.open("network", Popouts.screen)
            }

            Tile {
                visible: Config.bluetooth.enabled && !!root.adapter
                glyph: Icons.bluetooth(root.adapter?.enabled ?? false, root.connectedDevices.length)
                label: root.connectedDevices.length === 1 ? (root.connectedDevices[0].name ?? "Bluetooth") : "Bluetooth"
                on: root.adapter?.enabled ?? false
                hasDetail: true
                onToggled: root.adapter.enabled = !root.adapter.enabled
                onDetail: Popouts.open("bluetooth", Popouts.screen)
            }

            Tile {
                glyph: Icons.bellDnd
                label: "Do not disturb"
                on: Notifications.dnd
                onToggled: Notifications.toggleDnd()
            }

            Tile {
                glyph: Icons.powerProfile(PowerProfiles.profile)
                label: PowerProfiles.profile === PowerProfile.PowerSaver ? "Power saver" : (PowerProfiles.profile === PowerProfile.Performance ? "Performance" : "Balanced")
                on: PowerProfiles.profile !== PowerProfile.Balanced
                // Round the three modes, skipping Performance where the hardware has none.
                onToggled: {
                    if (PowerProfiles.profile === PowerProfile.Balanced)
                        PowerProfiles.profile = PowerProfile.PowerSaver;
                    else if (PowerProfiles.profile === PowerProfile.PowerSaver && PowerProfiles.hasPerformanceProfile)
                        PowerProfiles.profile = PowerProfile.Performance;
                    else
                        PowerProfiles.profile = PowerProfile.Balanced;
                }
            }

            Tile {
                glyph: "\u{F001D}"
                label: "Airplane mode"
                on: root.airplane
                onToggled: {
                    const flying = !root.airplane;
                    Networking.wifiEnabled = !flying;
                    if (root.adapter)
                        root.adapter.enabled = !flying;
                }
            }

            Tile {
                visible: Config.hue.enabled
                glyph: Icons.hue(Hue.anyOn, Hue.ready, Hue.stale)
                label: "Lights"
                on: Hue.anyOn
                hasDetail: true
                onToggled: Hue.setAll({
                    on: !Hue.anyOn
                })
                onDetail: Popouts.open("hue", Popouts.screen)
            }
        }

        // ── Sliders ─────────────────────────────────────────────────────────
        Row {
            visible: Brightness.available
            width: parent.width
            spacing: Theme.sp3

            Text {
                width: 28
                height: 28
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: Icons.brightness
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsIconLg
                color: Theme.textBright
            }

            StyledSlider {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 28 - Theme.sp3
                value: Brightness.value
                onMoved: value => Brightness.set(value)
            }
        }

        Row {
            width: parent.width
            spacing: Theme.sp3

            IconButton {
                id: muteButton
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 28
                implicitHeight: 28
                horizontalPadding: 0
                icon: Icons.volume(Audio.volume, Audio.muted, Audio.portType)
                fontSize: Theme.fsIconLg
                colour: Theme.textBright
                onClicked: Audio.toggleMute()
            }

            StyledSlider {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 28 - detailButton.width - Theme.sp3 * 2
                value: Audio.volume / Math.max(0.01, Audio.maxVolume)
                onMoved: value => Audio.setVolume(value * Audio.maxVolume)
            }

            IconButton {
                id: detailButton
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 28
                implicitHeight: 28
                horizontalPadding: 0
                icon: Icons.chevronRight
                colour: Theme.textBright
                tooltip: "Sound output"
                onClicked: Popouts.open("audio", Popouts.screen)
            }
        }

        // ── Footer ──────────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: 28

            // The strip runs edge to edge under the panel's own padding; being
            // inside this Item it does not count toward the panel's measured height.
            Rectangle {
                x: -root.padding
                y: -Theme.sp3
                width: root.panelWidth
                height: parent.height + Theme.sp3 + root.padding
                z: -1
                color: Theme.footerFill
                bottomLeftRadius: Theme.rPanel
                bottomRightRadius: Theme.rPanel

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.divider
                }
            }

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                visible: root.hasBattery
                spacing: Theme.sp2

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.battery((root.batteryDevice?.percentage ?? 0) * 100, root.charging)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsIconLg
                    color: Theme.textBright
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: `${Math.round((root.batteryDevice?.percentage ?? 0) * 100)}%`
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsSm
                    color: Theme.textBright
                }
            }

            IconButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                implicitHeight: 28
                icon: Icons.settings
                colour: Theme.textBright
                tooltip: "All settings"
                onClicked: {
                    Popouts.startView = "settings";
                    Popouts.open("start", Popouts.screen);
                }
            }
        }
    }

    // One toggle: a rounded button, split in two when it has a detail page, over a
    // caption. Accent-filled with dark glyphs while on.
    component Tile: Column {
        id: tile

        property string glyph: ""
        property string label: ""
        property bool on: false
        property bool hasDetail: false

        signal toggled
        signal detail

        width: root.tileWidth
        spacing: Theme.sp2

        Item {
            width: parent.width
            height: 48

            Rectangle {
                id: mainPart
                anchors.left: parent.left
                width: tile.hasDetail ? parent.width - detailPart.width - 1 : parent.width
                height: parent.height
                radius: Theme.rSm
                topRightRadius: tile.hasDetail ? 0 : Theme.rSm
                bottomRightRadius: tile.hasDetail ? 0 : Theme.rSm
                color: tile.on ? (toggleMouse.containsMouse ? Theme.alpha(Theme.accentBright, 0.9) : Theme.accentBright) : (toggleMouse.containsMouse ? Theme.subtleHover : Theme.controlFill)
                border.width: tile.on ? 0 : 1
                border.color: Theme.controlStroke

                Text {
                    anchors.centerIn: parent
                    text: tile.glyph
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsIconLg
                    color: tile.on ? Theme.onAccent : Theme.textBright
                }

                MouseArea {
                    id: toggleMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: tile.toggled()
                }
            }

            Rectangle {
                id: detailPart
                visible: tile.hasDetail
                anchors.right: parent.right
                width: 30
                height: parent.height
                radius: Theme.rSm
                topLeftRadius: 0
                bottomLeftRadius: 0
                color: tile.on ? (detailMouse.containsMouse ? Theme.alpha(Theme.accentBright, 0.9) : Theme.accentBright) : (detailMouse.containsMouse ? Theme.subtleHover : Theme.controlFill)
                border.width: tile.on ? 0 : 1
                border.color: Theme.controlStroke

                Text {
                    anchors.centerIn: parent
                    text: Icons.chevronRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsSm
                    color: tile.on ? Theme.onAccent : Theme.textBright
                }

                MouseArea {
                    id: detailMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: tile.detail()
                }
            }
        }

        Text {
            width: parent.width
            text: tile.label
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsSm
            color: Theme.textBright
        }
    }
}
