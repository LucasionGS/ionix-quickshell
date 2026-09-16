// Countdown timer, opened by right-clicking the clock.
//
// Set like a kitchen timer: an arrow above and below each of hours, minutes and
// seconds, and the scroll wheel over a field does the same. The panel is only a
// face on services/Countdown.qml — closing it leaves the count running, and the
// clock pill takes over showing it.
//
// While a count is running or paused the arrows go away and the digits show
// what is left, so there is never a question of whether a change applies to the
// run in progress. Reset brings the editor back with the last length set.

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

Popout {
    id: root

    panelWidth: 300

    readonly property bool editing: Countdown.phase === "idle"
    readonly property int shown: Countdown.remaining
    readonly property var presets: Config.clock.timer?.presets ?? [60, 300, 600, 1500]

    // Enter starts or pauses, like the big button.
    Shortcut {
        sequences: ["Return", "Enter", "Space"]
        enabled: root.shouldOpen
        onActivated: Countdown.ringing ? Countdown.dismiss() : Countdown.toggle()
    }

    Column {
        width: parent.width
        spacing: Theme.sp4

        SectionHeader {
            width: parent.width
            text: Countdown.ringing ? "Time's up" : "Timer"
            glyph: Countdown.ringing ? Icons.timerRing : Icons.timer
        }

        // ── Digits ──────────────────────────────────────────────────────────
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.sp1

            Repeater {
                model: [
                    {
                        unit: 3600,
                        label: "h"
                    },
                    {
                        unit: 60,
                        label: "m"
                    },
                    {
                        unit: 1,
                        label: "s"
                    }
                ]

                delegate: Row {
                    id: field
                    required property var modelData
                    required property int index

                    readonly property int value: field.modelData.unit === 3600 ? Math.floor(root.shown / 3600) : Math.floor(root.shown / field.modelData.unit) % 60

                    spacing: Theme.sp1

                    // Centred on the digits, not on the column: the unit label
                    // below them would otherwise pull the colon down.
                    Item {
                        visible: field.index > 0
                        width: colon.implicitWidth
                        height: fieldColumn.height

                        Text {
                            id: colon
                            y: digits.y + (digits.height - height) / 2
                            text: ":"
                            font.family: Theme.fontMono
                            font.pixelSize: 40
                            font.weight: Font.DemiBold
                            color: Theme.muted
                        }
                    }

                    Column {
                        id: fieldColumn
                        spacing: 0

                        IconButton {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: digits.implicitWidth
                            horizontalPadding: 0
                            icon: Icons.chevronUp
                            fontSize: Theme.fsIconLg
                            colour: Theme.accentLight
                            opacity: root.editing ? 1 : 0
                            enabled: root.editing
                            onClicked: Countdown.step(field.modelData.unit, 1)
                        }

                        Text {
                            id: digits
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: String(field.value).padStart(2, "0")
                            font.family: Theme.fontMono
                            font.pixelSize: 40
                            font.weight: Font.DemiBold
                            color: Countdown.ringing ? Theme.red : (Countdown.paused ? Theme.muted : Theme.textBright)

                            MouseArea {
                                anchors.fill: parent
                                enabled: root.editing
                                acceptedButtons: Qt.NoButton
                                onWheel: wheel => Countdown.step(field.modelData.unit, wheel.angleDelta.y > 0 ? 1 : -1)
                            }
                        }

                        IconButton {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: digits.implicitWidth
                            horizontalPadding: 0
                            icon: Icons.chevronDown
                            fontSize: Theme.fsIconLg
                            colour: Theme.accentLight
                            opacity: root.editing ? 1 : 0
                            enabled: root.editing
                            onClicked: Countdown.step(field.modelData.unit, -1)
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: field.modelData.label
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsXs
                            color: Theme.muted
                        }
                    }
                }
            }
        }

        // ── Presets ─────────────────────────────────────────────────────────
        // Only while editing: a preset replaces the length, it doesn't start.
        // Hidden by opacity so the panel keeps its height when a run starts —
        // on a bottom-anchored bar a shrinking panel would jump away from the cursor.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.sp2
            opacity: root.editing ? 1 : 0
            enabled: root.editing

            Repeater {
                model: root.presets

                delegate: Rectangle {
                    id: preset
                    required property var modelData

                    readonly property bool selected: Countdown.duration === preset.modelData

                    width: presetLabel.implicitWidth + Theme.sp5
                    height: 24
                    radius: Theme.rSm
                    color: preset.selected ? Theme.alpha(Theme.accentBright, 0.18) : (presetMouse.containsMouse ? Theme.alpha(Theme.hover, 0.5) : Theme.alpha(Theme.bgCard, 0.4))
                    border.width: 1
                    border.color: preset.selected ? Theme.alpha(Theme.accentBright, 0.35) : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durNormal
                        }
                    }

                    Text {
                        id: presetLabel
                        anchors.centerIn: parent
                        text: preset.modelData % 60 === 0 && preset.modelData < 3600 ? `${preset.modelData / 60}m` : Countdown.format(preset.modelData)
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsSm
                        color: preset.selected ? Theme.textBright : Theme.text
                    }

                    MouseArea {
                        id: presetMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Countdown.setDuration(preset.modelData)
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.divider
        }

        // ── Controls ────────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: 26

            IconButton {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.editing
                horizontalPadding: Theme.sp2
                icon: Icons.refresh
                label: "Reset"
                fontSize: Theme.fsMd
                colour: Theme.muted
                onClicked: Countdown.reset()
            }

            IconButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                horizontalPadding: Theme.sp3
                readonly property bool usable: Countdown.ringing || !root.editing || Countdown.duration > 0
                icon: Countdown.ringing ? Icons.stop : (Countdown.running ? Icons.pause : Icons.play)
                label: Countdown.ringing ? "Stop" : (Countdown.running ? "Pause" : (Countdown.paused ? "Resume" : "Start"))
                fontSize: Theme.fsMd
                colour: !usable ? Theme.border : (Countdown.ringing ? Theme.red : Theme.accentLight)
                hoverColour: !usable ? Theme.border : (Countdown.ringing ? Theme.red : Theme.accentBright)
                onClicked: {
                    if (Countdown.ringing)
                        Countdown.dismiss();
                    else
                        Countdown.toggle();
                }
            }
        }
    }
}
