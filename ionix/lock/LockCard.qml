// The unlock card: avatar in a ring that reports the check's state, the account
// name, the password field and one line of status under it.
//
// The ring is the feedback channel. It turns while a check runs, flashes red on
// a failure, turns green on success, and breathes while a fingerprint reader is
// listening, so what happened is readable from across the room even with the
// status text too small to make out.

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell.Widgets
import qs.config
import qs.services

Item {
    id: root

    readonly property string phase: LockState.unlocked ? "success" : LockState.phase
    readonly property color ringColour: {
        if (root.phase === "success")
            return Theme.green;
        if (root.phase === "failed")
            return Theme.red;
        return Theme.accentBright;
    }

    implicitWidth: 360
    implicitHeight: column.implicitHeight + Theme.sp7 + Theme.sp5

    // Shaken from outside on LockState.failed; a translate rather than moving x
    // so the layout that positions the card never sees it.
    transform: Translate {
        id: shakeOffset
    }

    SequentialAnimation {
        id: shake
        NumberAnimation {
            target: shakeOffset
            property: "x"
            to: -14
            duration: 50
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: shakeOffset
            property: "x"
            to: 12
            duration: 70
        }
        NumberAnimation {
            target: shakeOffset
            property: "x"
            to: -8
            duration: 70
        }
        NumberAnimation {
            target: shakeOffset
            property: "x"
            to: 4
            duration: 60
        }
        NumberAnimation {
            target: shakeOffset
            property: "x"
            to: 0
            duration: 60
            easing.type: Easing.OutQuad
        }
    }

    Connections {
        target: LockState
        function onFailed() {
            shake.restart();
        }
    }

    // Medium glass: this floats over the wallpaper, so it follows the drawer
    // convention rather than the bar's heavy fill.
    RectangularShadow {
        anchors.fill: glass
        radius: glass.radius
        blur: 64
        offset: Qt.vector2d(0, 18)
        color: Qt.rgba(0, 0, 0, 0.55)
    }

    Rectangle {
        id: glass
        anchors.fill: parent
        radius: Theme.rPanel + 6
        color: Theme.alpha(Theme.bgWindow, 0.6)
        border.width: 1
        border.color: Theme.alpha(root.ringColour, root.phase === "idle" ? 0.25 : 0.55)

        Behavior on border.color {
            ColorAnimation {
                duration: Theme.durSlow
            }
        }

        // Inner top highlight, as GlassPanel draws it.
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 1
            height: 1
            radius: parent.radius
            color: Qt.rgba(1, 1, 1, 0.05)
        }
    }

    Column {
        id: column
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Theme.sp7
        width: parent.width - Theme.sp7 * 2
        spacing: Theme.sp4

        // ── Avatar ──────────────────────────────────────────────────────────
        Item {
            id: avatar
            anchors.horizontalCenter: parent.horizontalCenter
            width: 104
            height: 104

            // The ring: a conical gradient around the picture. It spins
            // while checking and breathes while the fingerprint reader listens.
            Shape {
                id: ring
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                opacity: LockState.fingerprintScanning && root.phase === "idle" ? breathe.value : 1

                property real angle: 0

                NumberAnimation on angle {
                    running: root.phase === "checking"
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                }

                // A filled annulus rather than a stroked circle: ShapePath has
                // no stroke gradient, but an odd-even fill between two circles
                // takes the conical gradient fine.
                ShapePath {
                    strokeWidth: -1
                    strokeColor: "transparent"
                    fillRule: ShapePath.OddEvenFill
                    fillGradient: ConicalGradient {
                        centerX: ring.width / 2
                        centerY: ring.height / 2
                        angle: ring.angle
                        GradientStop {
                            position: 0
                            color: root.ringColour
                        }
                        GradientStop {
                            position: 0.5
                            color: Theme.alpha(root.phase === "idle" ? Theme.accentLight : root.ringColour, 0.3)
                        }
                        GradientStop {
                            position: 1
                            color: root.ringColour
                        }
                    }

                    PathAngleArc {
                        moveToStart: true
                        centerX: ring.width / 2
                        centerY: ring.height / 2
                        radiusX: ring.width / 2
                        radiusY: ring.height / 2
                        startAngle: 0
                        sweepAngle: 360
                    }
                    PathAngleArc {
                        moveToStart: true
                        centerX: ring.width / 2
                        centerY: ring.height / 2
                        radiusX: ring.width / 2 - 3
                        radiusY: ring.height / 2 - 3
                        startAngle: 0
                        sweepAngle: 360
                    }
                }
            }

            QtObject {
                id: breathe
                property real value: 1
                property SequentialAnimation anim: SequentialAnimation {
                    running: LockState.fingerprintScanning
                    loops: Animation.Infinite
                    NumberAnimation {
                        target: breathe
                        property: "value"
                        to: 0.35
                        duration: 1100
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        target: breathe
                        property: "value"
                        to: 1
                        duration: 1100
                        easing.type: Easing.InOutSine
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 9
                radius: Theme.rRound
                color: Theme.alpha(Theme.accent, 0.25)

                Text {
                    anchors.centerIn: parent
                    visible: avatarImage.status !== Image.Ready
                    text: Icons.account
                    font.family: Theme.fontFamily
                    font.pixelSize: 40
                    color: Theme.accentLight
                }
            }

            ClippingRectangle {
                anchors.fill: parent
                anchors.margins: 9
                radius: Theme.rRound
                color: "transparent"
                visible: avatarImage.status === Image.Ready

                Image {
                    id: avatarImage
                    anchors.fill: parent
                    source: SystemInfo.avatar
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: width * 2
                    sourceSize.height: height * 2
                }
            }
        }

        // ── Who ─────────────────────────────────────────────────────────────
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.sp1

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: SystemInfo.displayName
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsTitle
                font.weight: Font.DemiBold
                color: Theme.textBright
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: text !== ""
                text: SystemInfo.showsLogin ? (SystemInfo.host !== "" ? `${SystemInfo.user}@${SystemInfo.host}` : SystemInfo.user) : SystemInfo.host
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsSm
                color: Theme.muted
            }
        }

        Item {
            width: 1
            height: Theme.sp1
        }

        // ── Field ───────────────────────────────────────────────────────────
        Rectangle {
            id: field
            width: parent.width
            height: 48
            radius: height / 2
            color: Theme.alpha(Theme.bgDeep, 0.6)
            border.width: 1
            border.color: {
                if (root.phase === "failed")
                    return Theme.alpha(Theme.red, 0.8);
                if (LockState.buffer !== "" || root.phase === "checking")
                    return Theme.alpha(Theme.accentBright, 0.7);
                return Theme.alpha(Theme.border, 0.8);
            }

            Behavior on border.color {
                ColorAnimation {
                    duration: Theme.durNormal
                }
            }

            Text {
                id: lockGlyph
                anchors.left: parent.left
                anchors.leftMargin: Theme.sp5
                anchors.verticalCenter: parent.verticalCenter
                text: root.phase === "success" ? Icons.lockOpen : Icons.lock
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsIcon
                color: root.phase === "failed" ? Theme.red : (LockState.buffer !== "" ? Theme.accentLight : Theme.muted)

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durNormal
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: LockState.buffer === "" && root.phase !== "checking"
                text: LockState.fingerprintAvailable ? "Password or fingerprint" : "Password"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsBase
                color: Theme.muted
            }

            // One dot per character, capped so a long passphrase doesn't
            // overflow the field. They pop in as typed and ripple while the
            // check runs.
            Row {
                id: dots
                anchors.centerIn: parent
                spacing: 7
                readonly property int maxDots: Math.max(4, Math.floor((field.width - 120) / 16))

                Repeater {
                    model: Math.min(LockState.buffer.length, dots.maxDots)

                    Rectangle {
                        id: dot
                        required property int index
                        width: 9
                        height: 9
                        radius: 4.5
                        color: root.phase === "checking" ? Theme.accentBright : Theme.accentLight
                        scale: 0.2

                        Component.onCompleted: scale = 1

                        Behavior on scale {
                            NumberAnimation {
                                duration: 180
                                easing.type: Easing.OutBack
                            }
                        }

                        transform: Translate {
                            id: hop
                        }

                        SequentialAnimation {
                            running: root.phase === "checking"
                            loops: Animation.Infinite
                            onRunningChanged: if (!running)
                                hop.y = 0
                            PauseAnimation {
                                duration: dot.index * 70
                            }
                            NumberAnimation {
                                target: hop
                                property: "y"
                                to: -5
                                duration: 180
                                easing.type: Easing.OutQuad
                            }
                            NumberAnimation {
                                target: hop
                                property: "y"
                                to: 0
                                duration: 220
                                easing.type: Easing.InQuad
                            }
                            PauseAnimation {
                                duration: Math.max(0, (Math.min(LockState.buffer.length, dots.maxDots) - dot.index) * 70)
                            }
                        }
                    }
                }
            }

            // Right end: submit arrow when there is something to submit,
            // otherwise the fingerprint glyph when a reader is listening.
            Rectangle {
                id: submit
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                width: 36
                height: 36
                radius: Theme.rRound
                color: submitMouse.containsMouse ? Theme.accentBright : Theme.alpha(Theme.accent, 0.85)
                opacity: LockState.buffer !== "" && root.phase !== "checking" ? 1 : 0
                scale: opacity > 0 ? 1 : 0.6
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durNormal
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.durSlide
                        easing.type: Easing.OutBack
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durFast
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: Icons.arrowRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsIconLg
                    color: Theme.textBright
                }

                MouseArea {
                    id: submitMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: LockState.submit()
                }
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: Theme.sp5
                anchors.verticalCenter: parent.verticalCenter
                visible: LockState.fingerprintAvailable && !submit.visible
                text: Icons.fingerprint
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsIconLg
                color: LockState.fingerprintMessage !== "" ? Theme.orange : Theme.accentLight
                opacity: LockState.fingerprintScanning ? breathe.value : 0.6
            }
        }

        // ── Status ──────────────────────────────────────────────────────────
        // One line, most important first. Always takes its height, so the card
        // doesn't jump when a message comes and goes.
        Item {
            width: parent.width
            height: status.implicitHeight

            Text {
                id: status
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsSm

                readonly property var line: {
                    if (root.phase === "success")
                        return ["Welcome back", Theme.green];
                    if (root.phase === "checking")
                        return ["Checking…", Theme.accentLight];
                    if (LockState.message !== "")
                        return [LockState.message, Theme.red];
                    if (LockState.capsLock)
                        return [`${Icons.capsLock}  Caps Lock is on`, Theme.orange];
                    if (LockState.fingerprintMessage !== "")
                        return [LockState.fingerprintMessage, Theme.orange];
                    return [" ", Theme.muted];
                }
                text: line[0]
                color: line[1]
            }
        }
    }
}
