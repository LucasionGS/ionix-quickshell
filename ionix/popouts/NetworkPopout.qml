// Wi-Fi picker with inline password entry, plus wired status.
//
// Connects natively through Quickshell.Networking rather than shelling out to
// nmcli, which is what lets the failure reason come back and render inline.

import QtQuick
import Quickshell
import Quickshell.Networking
import qs.config
import qs.components
import qs.services

Popout {
    id: root

    panelWidth: 360

    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: Networking.devices.values.find(d => d.type === DeviceType.Wired) ?? null

    // Which network has its password field expanded, and the last failure text.
    property var pendingNetwork: null
    property string errorText: ""

    // Deduplicate by SSID (one row per network, not per BSSID) and sort strongest
    // first, with the connected network pinned to the top.
    readonly property var networks: {
        const list = root.wifiDevice?.networks?.values ?? [];
        const seen = {};
        const out = [];
        for (const n of list) {
            if (!n.name || n.name === "")
                continue;
            const prev = seen[n.name];
            if (prev === undefined) {
                seen[n.name] = out.length;
                out.push(n);
            } else if (n.signalStrength > out[prev].signalStrength || n.connected) {
                out[prev] = n;
            }
        }
        return out.sort((a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            return b.signalStrength - a.signalStrength;
        });
    }

    // Scanning is expensive; only run it while the panel is actually visible.
    onShouldOpenChanged: {
        if (root.wifiDevice)
            root.wifiDevice.scannerEnabled = root.shouldOpen;
        if (!root.shouldOpen) {
            root.pendingNetwork = null;
            root.errorText = "";
        }
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
                text: "Network"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsBase
                font.weight: Font.DemiBold
                color: Theme.textBright
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.sp3

                // Connectivity chip — distinguishes "associated" from "actually online",
                // which is the difference between a captive portal and a working link.
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Networking.connectivity !== NetworkConnectivity.Unknown
                    width: connLabel.implicitWidth + Theme.sp3
                    height: 18
                    radius: 9
                    color: Theme.alpha(root.connectivityColour(), 0.16)
                    border.width: 1
                    border.color: Theme.alpha(root.connectivityColour(), 0.4)

                    Text {
                        id: connLabel
                        anchors.centerIn: parent
                        text: root.connectivityLabel()
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsXs
                        color: root.connectivityColour()
                    }
                }

                Switch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: Networking.wifiEnabled
                    enabled: Networking.wifiHardwareEnabled
                    onToggled: v => Networking.wifiEnabled = v
                }
            }
        }

        // ── Wired ───────────────────────────────────────────────────────────
        ListRow {
            width: parent.width
            visible: !!root.wiredDevice
            icon: Icons.ethernet
            iconColour: root.wiredDevice?.connected ? Theme.green : Theme.muted
            title: root.wiredDevice?.name ?? "Ethernet"
            subtitle: root.wiredDevice?.connected ? (root.wiredDevice.address ?? "Connected") : "Not connected"

            Text {
                visible: root.wiredDevice?.connected ?? false
                text: Icons.check
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsMd
                color: Theme.green
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.divider
            visible: !!root.wiredDevice
        }

        // ── Error banner ────────────────────────────────────────────────────
        Rectangle {
            width: parent.width
            visible: root.errorText !== ""
            height: visible ? errLabel.implicitHeight + Theme.sp3 : 0
            radius: Theme.rSm
            color: Theme.alpha(Theme.red, 0.14)
            border.width: 1
            border.color: Theme.alpha(Theme.red, 0.35)

            Text {
                id: errLabel
                anchors.centerIn: parent
                width: parent.width - Theme.sp4
                text: root.errorText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsSm
                color: Theme.red
                wrapMode: Text.WordWrap
            }
        }

        // ── Wi-Fi list ──────────────────────────────────────────────────────
        Text {
            width: parent.width
            visible: Networking.wifiEnabled && root.networks.length === 0
            horizontalAlignment: Text.AlignHCenter
            text: root.wifiDevice ? "Scanning…" : "No Wi-Fi adapter"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsSm
            color: Theme.muted
        }

        Text {
            width: parent.width
            visible: !Networking.wifiEnabled
            horizontalAlignment: Text.AlignHCenter
            text: "Wi-Fi is off"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsSm
            color: Theme.muted
        }

        Column {
            width: parent.width
            spacing: 2
            visible: Networking.wifiEnabled

            Repeater {
                model: root.networks

                delegate: Column {
                    id: netEntry
                    required property var modelData
                    width: parent.width
                    spacing: 0

                    readonly property bool expanded: root.pendingNetwork === modelData

                    ListRow {
                        width: parent.width
                        icon: Icons.wifi(netEntry.modelData.signalStrength)
                        title: netEntry.modelData.name
                        subtitle: {
                            if (netEntry.modelData.connected)
                                return "Connected";
                            if (netEntry.modelData.stateChanging)
                                return "Connecting…";
                            return `${Math.round(netEntry.modelData.signalStrength * 100)}%` + (netEntry.modelData.known ? "  ·  saved" : "");
                        }
                        selected: netEntry.modelData.connected
                        busy: netEntry.modelData.stateChanging

                        onClicked: {
                            root.errorText = "";
                            const n = netEntry.modelData;
                            if (n.connected) {
                                n.disconnect();
                                return;
                            }
                            // A saved network or an open one can connect straight away;
                            // anything else needs a passphrase first.
                            if (n.known || n.security === WifiSecurityType.Open) {
                                n.connect();
                                root.pendingNetwork = null;
                            } else {
                                root.pendingNetwork = netEntry.expanded ? null : n;
                            }
                        }

                        onRightClicked: {
                            if (netEntry.modelData.known)
                                netEntry.modelData.forget();
                        }

                        Row {
                            spacing: Theme.sp2

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Icons.security(netEntry.modelData.security)
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsSm
                                color: Theme.muted
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: netEntry.modelData.connected
                                text: Icons.check
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsMd
                                color: Theme.green
                            }
                        }
                    }

                    // Inline passphrase entry.
                    Item {
                        width: parent.width
                        height: netEntry.expanded ? 38 : 0
                        clip: true
                        visible: height > 0

                        Behavior on height {
                            NumberAnimation {
                                duration: Theme.durNormal
                                easing.type: Theme.easeStandard
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.topMargin: 4
                            anchors.leftMargin: Theme.sp5
                            anchors.bottomMargin: 4
                            radius: Theme.rSm
                            color: Theme.alpha(Theme.bgDeep, 0.7)
                            border.width: 1
                            border.color: pwField.activeFocus ? Theme.accentBright : Theme.border

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: Theme.durNormal
                                }
                            }

                            TextInput {
                                id: pwField
                                anchors.fill: parent
                                anchors.leftMargin: Theme.sp3
                                anchors.rightMargin: 34
                                verticalAlignment: TextInput.AlignVCenter
                                echoMode: TextInput.Password
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsMd
                                color: Theme.textBright
                                selectionColor: Theme.alpha(Theme.accentBright, 0.4)
                                clip: true
                                focus: netEntry.expanded

                                onAccepted: netEntry.submit()

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: pwField.text === ""
                                    text: "Password"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsMd
                                    color: Theme.muted
                                }
                            }

                            IconButton {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalPadding: Theme.sp2
                                icon: Icons.chevronRight
                                fontSize: Theme.fsMd
                                colour: pwField.text === "" ? Theme.border : Theme.accentBright
                                onClicked: netEntry.submit()
                            }
                        }
                    }

                    function submit() {
                        if (pwField.text === "")
                            return;
                        root.errorText = "";
                        netEntry.modelData.connectWithPsk(pwField.text);
                        pwField.text = "";
                        root.pendingNetwork = null;
                    }

                    Connections {
                        target: netEntry.modelData
                        function onConnectionFailed(reason) {
                            root.errorText = `${netEntry.modelData.name}: ${root.failText(reason)}`;
                            if (reason === ConnectionFailReason.NoSecrets)
                                root.pendingNetwork = netEntry.modelData;
                        }
                    }
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
                label: "Network settings"
                fontSize: Theme.fsMd
                colour: Theme.muted
                onClicked: {
                    Popouts.close();
                    Quickshell.execDetached(["nm-connection-editor"]);
                }
            }
        }
    }

    function connectivityLabel() {
        switch (Networking.connectivity) {
        case NetworkConnectivity.Full:
            return "Online";
        case NetworkConnectivity.Portal:
            return "Sign-in required";
        case NetworkConnectivity.Limited:
            return "Limited";
        case NetworkConnectivity.None:
            return "Offline";
        default:
            return "Unknown";
        }
    }

    function connectivityColour() {
        switch (Networking.connectivity) {
        case NetworkConnectivity.Full:
            return Theme.green;
        case NetworkConnectivity.Portal:
        case NetworkConnectivity.Limited:
            return Theme.orange;
        case NetworkConnectivity.None:
            return Theme.red;
        default:
            return Theme.muted;
        }
    }

    function failText(reason) {
        switch (reason) {
        case ConnectionFailReason.NoSecrets:
            return "wrong password";
        case ConnectionFailReason.WifiAuthTimeout:
            return "authentication timed out";
        case ConnectionFailReason.WifiNetworkLost:
            return "network went away";
        case ConnectionFailReason.WifiClientDisconnected:
            return "disconnected";
        case ConnectionFailReason.WifiClientFailed:
            return "connection failed";
        default:
            return "connection failed";
        }
    }
}
