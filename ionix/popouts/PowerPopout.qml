// Session actions, plus power profiles on machines that expose them.
//
// The destructive actions (reboot, shutdown, logout) need a second click within
// three seconds. A power menu one stray click away from ending your session is a
// bad menu, and a confirmation dialog would be heavier than the menu itself.

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.config
import qs.components
import qs.services

Popout {
    id: root

    panelWidth: 300

    // Which tile is currently armed for confirmation, "" when none.
    property string armed: ""

    onShouldOpenChanged: if (!shouldOpen)
        root.armed = ""

    Timer {
        id: disarm
        interval: 3000
        onTriggered: root.armed = ""
    }

    readonly property var actions: [
        {
            id: "lock",
            label: "Lock",
            icon: Icons.lock,
            colour: Theme.accentBright,
            confirm: false,
            command: Config.power.lock
        },
        {
            id: "logout",
            label: "Log out",
            icon: Icons.logout,
            colour: Theme.orange,
            confirm: true,
            command: Config.power.logout
        },
        {
            id: "suspend",
            label: "Suspend",
            icon: Icons.suspend,
            colour: Theme.accentBright,
            confirm: false,
            command: Config.power.suspend
        },
        {
            id: "hibernate",
            label: "Hibernate",
            icon: Icons.hibernate,
            colour: Theme.accentBright,
            confirm: false,
            command: Config.power.hibernate
        },
        {
            id: "reboot",
            label: "Restart",
            icon: Icons.reboot,
            colour: Theme.red,
            confirm: true,
            command: Config.power.reboot
        },
        {
            id: "shutdown",
            label: "Shut down",
            icon: Icons.shutdown,
            colour: Theme.red,
            confirm: true,
            command: Config.power.shutdown
        }
    ]

    Column {
        width: parent.width
        spacing: Theme.sp4

        // ── Battery detail ──────────────────────────────────────────────────
        Item {
            width: parent.width
            height: 18
            visible: !!UPower.displayDevice?.isLaptopBattery

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    const d = UPower.displayDevice;
                    if (!d)
                        return "";
                    // percentage is a 0..1 fraction, not 0..100.
                    return `${Math.round(d.percentage * 100)}%  ·  ${UPowerDeviceState.toString(d.state)}`;
                }
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsSm
                color: Theme.muted
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: UPower.onBattery
                text: {
                    const d = UPower.displayDevice;
                    if (!d || d.timeToEmpty <= 0)
                        return "";
                    const m = Math.round(d.timeToEmpty / 60);
                    return `${Math.floor(m / 60)}h ${m % 60}m left`;
                }
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsSm
                color: Theme.text
            }
        }

        // ── Power profiles ──────────────────────────────────────────────────
        Row {
            width: parent.width
            height: 30
            spacing: Theme.sp1
            visible: PowerProfiles.hasPerformanceProfile

            Repeater {
                model: [
                    {
                        p: PowerProfile.PowerSaver,
                        label: "Saver"
                    },
                    {
                        p: PowerProfile.Balanced,
                        label: "Balanced"
                    },
                    {
                        p: PowerProfile.Performance,
                        label: "Performance"
                    }
                ]

                delegate: Rectangle {
                    required property var modelData
                    readonly property bool current: PowerProfiles.profile === modelData.p

                    width: (parent.width - Theme.sp1 * 2) / 3
                    height: 30
                    radius: Theme.rSm
                    color: current ? Theme.alpha(Theme.accentBright, 0.2) : (profMouse.containsMouse ? Theme.alpha(Theme.hover, 0.5) : Theme.alpha(Theme.bgCard, 0.3))
                    border.width: 1
                    border.color: current ? Theme.alpha(Theme.accentBright, 0.4) : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durNormal
                        }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.sp1

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Icons.powerProfile(modelData.p)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsSm
                            color: current ? Theme.accentBright : Theme.muted
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsXs
                            color: current ? Theme.textBright : Theme.muted
                        }
                    }

                    MouseArea {
                        id: profMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: PowerProfiles.profile = modelData.p
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.divider
            visible: PowerProfiles.hasPerformanceProfile
        }

        // ── Action grid ─────────────────────────────────────────────────────
        Grid {
            width: parent.width
            columns: 3
            spacing: Theme.sp2

            Repeater {
                model: root.actions

                delegate: Rectangle {
                    id: tile
                    required property var modelData
                    readonly property bool isArmed: root.armed === modelData.id

                    width: (parent.width - Theme.sp2 * 2) / 3
                    height: 74
                    radius: Theme.rPill
                    color: {
                        if (tile.isArmed)
                            return Theme.alpha(modelData.colour, 0.3);
                        return tileMouse.containsMouse ? Theme.alpha(modelData.colour, 0.15) : Theme.alpha(Theme.bgCard, 0.3);
                    }
                    border.width: 1
                    border.color: tile.isArmed ? modelData.colour : (tileMouse.containsMouse ? Theme.alpha(modelData.colour, 0.4) : "transparent")

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durNormal
                        }
                    }
                    Behavior on border.color {
                        ColorAnimation {
                            duration: Theme.durNormal
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.sp1

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: tile.modelData.icon
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsIconLg
                            color: tileMouse.containsMouse || tile.isArmed ? tile.modelData.colour : Theme.text
                            scale: tileMouse.containsMouse ? 1.12 : 1.0

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.durNormal
                                }
                            }
                            Behavior on scale {
                                NumberAnimation {
                                    duration: Theme.durFast
                                    easing.type: Theme.easeOvershoot
                                }
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: tile.width - Theme.sp2
                            horizontalAlignment: Text.AlignHCenter
                            text: tile.isArmed ? "Click again" : tile.modelData.label
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsXs
                            font.weight: tile.isArmed ? Font.Bold : Font.Normal
                            color: tile.isArmed ? tile.modelData.colour : Theme.muted
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: tileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (tile.modelData.confirm && !tile.isArmed) {
                                root.armed = tile.modelData.id;
                                disarm.restart();
                                return;
                            }
                            disarm.stop();
                            root.armed = "";
                            Popouts.close();
                            Quickshell.execDetached(tile.modelData.command);
                        }
                    }
                }
            }
        }
    }
}
