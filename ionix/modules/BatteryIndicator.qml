// Battery.
//
// Drawn as an actual battery outline with a proportional fill rather than picking
// from a glyph ramp — the fill reads continuously instead of snapping between 11
// discrete icons, and the colour carries the warning state without a second cue.
//
// Hides itself entirely when there's no laptop battery, which covers desktops and
// QEMU without any configuration.

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.config
import qs.components
import qs.popouts
import qs.services

Item {
    id: root

    property var bar: null

    readonly property var device: UPower.displayDevice
    readonly property bool present: !!root.device?.isLaptopBattery
    // UPowerDevice.percentage is a 0..1 fraction despite the name — scale it once
    // here so the thresholds and fill width below can read as real percentages.
    readonly property real percent: (root.device?.percentage ?? 0) * 100
    readonly property bool charging: root.device?.state === UPowerDeviceState.Charging || root.device?.state === UPowerDeviceState.FullyCharged
    readonly property bool critical: root.percent <= Config.battery.criticalAt && !root.charging

    readonly property color stateColour: root.charging ? Theme.green : Theme.levelColour(root.percent / 100)

    visible: root.present
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    IconButton {
        id: button
        anchors.fill: parent
        vertical: Config.barVertical
        colour: root.stateColour
        hoverColour: root.stateColour
        horizontalPadding: Theme.sp3
        icon: ""   // the battery is drawn below, not glyphed

        tooltip: {
            if (!root.device)
                return "";
            const pct = `${Math.round(root.percent)}%`;
            const rate = root.device.changeRate > 0 ? `  ·  ${root.device.changeRate.toFixed(1)}W` : "";
            if (root.charging) {
                const t = root.device.timeToFull;
                return t > 0 ? `${pct} · ${formatDuration(t)} until full${rate}` : `${pct} · charging${rate}`;
            }
            const t = root.device.timeToEmpty;
            return t > 0 ? `${pct} · ${formatDuration(t)} remaining${rate}` : `${pct}${rate}`;
        }

        onClicked: Popouts.toggle("power", root.bar?.screen)

        // The gauge is drawn into IconButton's overlay slot rather than being a
        // glyph, so the button has no content of its own to measure and its own
        // implicit size would come out as bare padding. Stating it here from the
        // gauge is what keeps the module from underlapping what it draws.
        implicitWidth: Config.barVertical ? Theme.pillHeight : gauge.implicitWidth + button.horizontalPadding * 2
        implicitHeight: Config.barVertical ? gauge.implicitHeight + button.horizontalPadding * 2 : Theme.pillHeight

        Grid {
            id: gauge
            anchors.centerIn: parent
            rows: Config.barVertical ? 2 : 1
            columns: Config.barVertical ? 1 : 2
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter
            spacing: Theme.sp2

            // ── The battery ────────────────────────────────────────────────
            Item {
                width: 24
                height: 12

                Rectangle {
                    id: shell
                    width: 22
                    height: 12
                    radius: 3.5
                    color: "transparent"
                    border.width: 1.5
                    border.color: root.stateColour

                    Behavior on border.color {
                        ColorAnimation {
                            duration: Theme.durSlow
                        }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 2
                        width: Math.max(1, (parent.width - 4) * Math.min(1, root.percent / 100))
                        height: parent.height - 4
                        radius: 1.5
                        color: root.stateColour

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.durSlide
                                easing.type: Theme.easeStandard
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.durSlow
                            }
                        }

                        // Breathing fill while charging.
                        SequentialAnimation on opacity {
                            running: root.charging
                            loops: Animation.Infinite
                            alwaysRunToEnd: true
                            NumberAnimation {
                                to: 0.45
                                duration: 1100
                                easing.type: Easing.InOutSine
                            }
                            NumberAnimation {
                                to: 1.0
                                duration: 1100
                                easing.type: Easing.InOutSine
                            }
                        }
                    }
                }

                // Terminal nub.
                Rectangle {
                    anchors.left: shell.right
                    anchors.verticalCenter: shell.verticalCenter
                    width: 2
                    height: 5
                    radius: 1
                    color: root.stateColour
                }

                Text {
                    anchors.centerIn: shell
                    visible: root.charging
                    text: Icons.charging
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    color: Theme.bgDeep
                }
            }

            // Percentage, revealed on hover so the bar stays quiet the rest of the
            // time. It collapses along whichever axis the gauge runs, so the
            // reveal pushes the bar's neighbours rather than the battery outline.
            Text {
                id: percentLabel
                text: `${Math.round(root.percent)}%`
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsSm
                font.weight: Font.DemiBold
                color: root.stateColour
                opacity: button.hovered || root.critical ? 1 : 0
                width: (Config.barVertical || opacity > 0) ? implicitWidth : 0
                height: (!Config.barVertical || opacity > 0) ? implicitHeight : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durNormal
                    }
                }
                Behavior on width {
                    NumberAnimation {
                        duration: Theme.durNormal
                        easing.type: Theme.easeStandard
                    }
                }
                Behavior on height {
                    NumberAnimation {
                        duration: Theme.durNormal
                        easing.type: Theme.easeStandard
                    }
                }
            }
        }
    }

    // Critical: pulse the whole module rather than just recolouring, so it's
    // noticeable from peripheral vision.
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 2
        anchors.bottomMargin: 2
        z: -1
        radius: Theme.rSm
        color: Theme.alpha(Theme.red, 0.15)
        visible: root.critical

        SequentialAnimation on opacity {
            running: root.critical
            loops: Animation.Infinite
            alwaysRunToEnd: true
            NumberAnimation {
                to: 0.2
                duration: 1000
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                to: 1.0
                duration: 1000
                easing.type: Easing.InOutSine
            }
        }
    }

    function formatDuration(seconds) {
        const total = Math.round(seconds / 60);
        const h = Math.floor(total / 60);
        const m = total % 60;
        if (h > 0)
            return `${h}h ${m}m`;
        return `${m}m`;
    }
}
