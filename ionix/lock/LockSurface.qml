// One monitor's lock screen.
//
// Two states, both driven by LockState.awake. Awake: the clock sits high, the
// unlock card is up in the middle over a blurred background, and the media card
// and power buttons sit along the bottom. Screensaver: everything but the clock
// fades away, the background clears and starts drifting, and the clock moves to
// the middle and wanders a little every minute so nothing burns in. Any key or
// mouse movement flips it back.
//
// Every monitor shows the full card. Keys typed on whichever surface has focus
// land in LockState, so the dots appear everywhere at once and it never matters
// which output the compositor chose.

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.UPower
import qs.config
import qs.services

WlSessionLockSurface {
    id: surface

    readonly property bool awake: LockState.awake && !LockState.unlocked
    readonly property bool leaving: LockState.unlocked
    // Flipped a frame after creation so everything animates in instead of
    // appearing fully formed.
    property bool entered: false
    readonly property bool compact: content.height < 700 || content.width < 900

    color: Theme.bgDeep

    Timer {
        interval: 30
        running: true
        onTriggered: surface.entered = true
    }

    LockBackground {
        id: background
        anchors.fill: parent
        screenName: surface.screen?.name ?? ""
        screenIndex: Math.max(0, Quickshell.screens.indexOf(surface.screen))
        awake: surface.awake
        leaving: surface.leaving
        glowCentre: Qt.point(card.x + card.width / 2, card.y + card.height / 2)
        glowStrength: surface.entered && !surface.leaving ? 1 : 0
    }

    Item {
        id: content
        anchors.fill: parent
        focus: true
        opacity: surface.entered && !surface.leaving ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: surface.leaving ? 260 : 450
                easing.type: Easing.OutCubic
            }
        }

        Keys.onPressed: event => {
            event.accepted = LockState.key(event);
        }

        // Activity. At the bottom of the stack so every button above still gets
        // its own clicks; small movements are ignored, because a mouse on a desk
        // reports jitter and would otherwise keep the card up forever.
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.AllButtons
            cursorShape: surface.awake ? Qt.ArrowCursor : Qt.BlankCursor

            property point last: Qt.point(-1, -1)

            onPositionChanged: mouse => {
                if (last.x >= 0 && Math.abs(mouse.x - last.x) + Math.abs(mouse.y - last.y) > 6)
                    LockState.poke();
                last = Qt.point(mouse.x, mouse.y);
            }
            onPressed: LockState.poke()
            onWheel: LockState.poke()
        }

        // ── Clock ───────────────────────────────────────────────────────────
        SystemClock {
            id: clock
            precision: SystemClock.Minutes
        }

        // Screensaver wander: a new offset each minute, well inside the screen.
        property point wander: Qt.point(0, 0)

        Timer {
            interval: 60000
            running: !surface.awake && Config.lock.screensaver?.motion !== false
            repeat: true
            onTriggered: content.wander = Qt.point((Math.random() - 0.5) * content.width * 0.3, (Math.random() - 0.5) * content.height * 0.3)
        }

        // A soft dark pool behind the clock once the blur and dim have gone,
        // so it stays legible over a bright picture. Follows the clock as it
        // wanders; invisible while the card is up, where the dim does this job.
        Shape {
            id: clockScrim
            readonly property real r: Math.max(clockBlock.width, clockBlock.height) * 0.95
            x: clockBlock.x + clockBlock.width / 2 - r
            y: clockBlock.y + clockBlock.height / 2 - r
            width: r * 2
            height: r * 2
            opacity: surface.awake ? 0 : 1
            preferredRendererType: Shape.CurveRenderer

            Behavior on opacity {
                NumberAnimation {
                    duration: 900
                }
            }

            ShapePath {
                strokeWidth: -1
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: clockScrim.r
                    centerY: clockScrim.r
                    centerRadius: clockScrim.r
                    focalX: centerX
                    focalY: centerY
                    GradientStop {
                        position: 0
                        color: Theme.alpha(Theme.bgDeep, 0.5)
                    }
                    GradientStop {
                        position: 0.55
                        color: Theme.alpha(Theme.bgDeep, 0.28)
                    }
                    GradientStop {
                        position: 1
                        color: "transparent"
                    }
                }
                PathAngleArc {
                    centerX: clockScrim.r
                    centerY: clockScrim.r
                    radiusX: clockScrim.r
                    radiusY: clockScrim.r
                    startAngle: 0
                    sweepAngle: 360
                }
            }
        }

        Column {
            id: clockBlock
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: surface.awake ? 0 : content.wander.x
            y: surface.awake ? Math.max(Theme.sp7, card.y - height - (surface.compact ? Theme.sp6 : content.height * 0.07)) : (content.height - height) / 2 + content.wander.y
            spacing: 0
            scale: surface.awake ? 1 : 1.18

            Behavior on y {
                NumberAnimation {
                    duration: 900
                    easing.type: Easing.InOutCubic
                }
            }
            Behavior on anchors.horizontalCenterOffset {
                NumberAnimation {
                    duration: 900
                    easing.type: Easing.InOutCubic
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 900
                    easing.type: Easing.InOutCubic
                }
            }

            readonly property int timeSize: Math.round(Math.min(content.width * 0.2, content.height * (surface.compact ? 0.13 : 0.16), 150))

            Text {
                id: time
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    const f = (Config.lock.clockFormat ?? "") !== "" ? Config.lock.clockFormat : (Config.clock.format ?? "HH:mm");
                    return Qt.formatDateTime(clock.date, f);
                }
                font.family: Theme.fontFamily
                font.pixelSize: clockBlock.timeSize
                font.weight: Font.Light
                font.letterSpacing: -clockBlock.timeSize * 0.03
                color: Theme.textBright

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Qt.rgba(0, 0, 0, 0.6)
                    shadowBlur: 0.8
                    shadowVerticalOffset: 4
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, Config.lock.dateFormat ?? "dddd d MMMM").toUpperCase()
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(Theme.fsLg, Math.round(clockBlock.timeSize * 0.13))
                font.weight: Font.DemiBold
                font.letterSpacing: Math.max(2, clockBlock.timeSize * 0.035)
                color: Theme.accentLight

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Qt.rgba(0, 0, 0, 0.85)
                    shadowBlur: 0.7
                    shadowVerticalOffset: 2
                }
            }
        }

        // ── Card ────────────────────────────────────────────────────────────
        LockCard {
            id: card
            width: Math.min(380, content.width - Theme.sp7 * 2)
            height: implicitHeight
            x: (content.width - width) / 2
            y: (content.height - height) / 2 + content.height * 0.06 + (surface.awake ? 0 : Theme.sp7)
            opacity: surface.awake ? 1 : 0
            visible: opacity > 0
            scale: surface.awake ? 1 : 0.96

            Behavior on opacity {
                NumberAnimation {
                    duration: surface.awake ? 380 : 600
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on y {
                NumberAnimation {
                    duration: 600
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 600
                    easing.type: Easing.OutCubic
                }
            }
        }

        // ── Bottom row ──────────────────────────────────────────────────────
        Item {
            id: bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Theme.sp7
            height: 64
            opacity: surface.awake ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 500
                    easing.type: Easing.OutCubic
                }
            }

            // Brand, bottom left.
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.sp3
                visible: !surface.compact

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Config.launcher.icon
                    font.family: Theme.fontLogo
                    font.pixelSize: 26
                    color: Theme.accentLight
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: SystemInfo.host
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMd
                    color: Theme.muted
                }
            }

            LockMediaCard {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                // Centred, so it may only use what the wider side leaves it.
                width: Math.min(360, bottom.width - 2 * (rightCluster.width + Theme.sp4))
                visible: Config.lock.media !== false && Player.active
            }

            // Battery and power, bottom right.
            Row {
                id: rightCluster
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.sp2

                Row {
                    id: battery
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.sp2
                    rightPadding: Theme.sp4

                    readonly property var device: UPower.displayDevice
                    readonly property real percent: (device?.percentage ?? 0) * 100
                    readonly property bool charging: device?.state === UPowerDeviceState.Charging || device?.state === UPowerDeviceState.FullyCharged
                    visible: !!device?.isLaptopBattery

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.battery(battery.percent, battery.charging)
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsIconLg
                        color: battery.charging ? Theme.green : Theme.levelColour(battery.percent / 100)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: `${Math.round(battery.percent)}%`
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsMd
                        color: Theme.text
                    }
                }

                LockPowerButtons {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Config.lock.power !== false
                }
            }
        }
    }
}
