// Volume / brightness on-screen display.
//
// Layer Overlay with exclusion ignored and focus off, so it floats over
// fullscreen windows without ever stealing input or reserving space.

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

PanelWindow {
    id: root

    required property var modelData
    screen: root.modelData

    WlrLayershell.namespace: "ionix-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    visible: Osd.visible || fadeHold.running
    focusable: false
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        bottom: true
        left: true
        right: true
    }
    margins.bottom: Config.osd.margin

    implicitHeight: 64

    // Keep the surface mapped long enough for the exit animation to finish.
    Timer {
        id: fadeHold
        interval: Theme.durSlide
    }

    Connections {
        target: Osd
        function onVisibleChanged() {
            if (!Osd.visible)
                fadeHold.restart();
        }
    }

    readonly property color tint: Osd.kind === "brightness" ? Theme.orange : (Osd.muted ? Theme.red : Theme.accentBright)

    Item {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: 260
        height: 60

        opacity: Osd.visible ? 1 : 0
        y: Osd.visible ? 0 : 12

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durNormal
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: Theme.durSlide
                easing.type: Theme.easeStandard
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.rPanel
            color: Theme.alpha(Theme.bgDeep, 0.9)
            border.width: 1
            border.color: Theme.alpha(root.tint, 0.3)
        }

        Text {
            id: glyph
            anchors.left: parent.left
            anchors.leftMargin: Theme.sp5
            anchors.verticalCenter: parent.verticalCenter
            text: Osd.kind === "brightness" ? Icons.brightness : Icons.volume(Osd.value, Osd.muted, "default")
            font.family: Theme.fontFamily
            font.pixelSize: 22
            color: root.tint

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durNormal
                }
            }
        }

        Rectangle {
            id: track
            anchors.left: glyph.right
            anchors.leftMargin: Theme.sp4
            anchors.right: percent.left
            anchors.rightMargin: Theme.sp3
            anchors.verticalCenter: parent.verticalCenter
            height: 6
            radius: 3
            color: Theme.alpha(Theme.border, 0.5)

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, Osd.value))
                height: parent.height
                radius: parent.radius
                color: Osd.muted ? Theme.border : root.tint

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.durFast
                        easing.type: Theme.easeStandard
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durNormal
                    }
                }
            }
        }

        Text {
            id: percent
            anchors.right: parent.right
            anchors.rightMargin: Theme.sp5
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            horizontalAlignment: Text.AlignRight
            text: Osd.muted ? "—" : `${Math.round(Osd.value * 100)}`
            font.family: Theme.fontMono
            font.pixelSize: Theme.fsBase
            font.weight: Font.DemiBold
            color: Theme.textBright
        }
    }
}
