// Audio mixer: master volume, output/input device pickers, per-application sliders.
//
// The per-app tab is the thing waybar structurally could not do — each stream is
// a real Pipewire node with its own volume, not a shell-out to pavucontrol.

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.config
import qs.components
import qs.services

Popout {
    id: root

    panelWidth: 360
    property int tab: 0     // 0 output, 1 input, 2 apps

    Column {
        width: parent.width
        spacing: Theme.sp4

        // ── Tabs ────────────────────────────────────────────────────────────
        Row {
            width: parent.width
            height: 30
            spacing: Theme.sp1

            Repeater {
                model: [
                    {
                        label: "Output",
                        icon: Icons.speaker
                    },
                    {
                        label: "Input",
                        icon: Icons.microphone
                    },
                    {
                        label: "Apps",
                        icon: Icons.apps
                    }
                ]

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    width: (parent.width - Theme.sp1 * 2) / 3
                    height: 30
                    radius: Theme.rSm
                    color: root.tab === index ? Theme.alpha(Theme.accentBright, 0.18) : (tabMouse.containsMouse ? Theme.alpha(Theme.hover, 0.5) : "transparent")
                    border.width: 1
                    border.color: root.tab === index ? Theme.alpha(Theme.accentBright, 0.35) : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durNormal
                        }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.sp2

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.icon
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsMd
                            color: root.tab === index ? Theme.accentBright : Theme.muted
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsSm
                            font.weight: root.tab === index ? Font.DemiBold : Font.Normal
                            color: root.tab === index ? Theme.textBright : Theme.muted
                        }
                    }

                    MouseArea {
                        id: tabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.tab = index
                    }
                }
            }
        }

        // ── Master ──────────────────────────────────────────────────────────
        Column {
            width: parent.width
            spacing: Theme.sp2
            visible: root.tab < 2

            Item {
                width: parent.width
                height: 20

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.tab === 0 ? Audio.description : (Audio.source?.description ?? "No input")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsSm
                    color: Theme.muted
                    elide: Text.ElideRight
                    width: parent.width - 50
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: `${Math.round((root.tab === 0 ? Audio.volume : Audio.sourceVolume) * 100)}%`
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsSm
                    font.weight: Font.DemiBold
                    color: Theme.textBright
                }
            }

            Row {
                width: parent.width
                spacing: Theme.sp3

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalPadding: 0
                    icon: root.tab === 0 ? Icons.volume(Audio.volume, Audio.muted, Audio.portType) : Icons.microphoneIcon(Audio.sourceMuted)
                    colour: (root.tab === 0 ? Audio.muted : Audio.sourceMuted) ? Theme.red : Theme.accentLight
                    onClicked: root.tab === 0 ? Audio.toggleMute() : Audio.toggleSourceMute()
                }

                StyledSlider {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 40
                    value: root.tab === 0 ? Audio.volume / Audio.maxVolume : Audio.sourceVolume
                    enabled: root.tab === 0 ? !Audio.muted : !Audio.sourceMuted
                    onMoved: v => {
                        if (root.tab === 0)
                            Audio.setVolume(v * Audio.maxVolume);
                        else if (Audio.source?.audio)
                            Audio.source.audio.volume = v;
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.divider
            visible: root.tab < 2
        }

        // ── Device list ─────────────────────────────────────────────────────
        Column {
            width: parent.width
            spacing: 2
            visible: root.tab < 2

            Repeater {
                model: root.tab === 0 ? Audio.sinks : Audio.sources

                delegate: ListRow {
                    id: deviceRow
                    required property PwNode modelData

                    width: parent.width
                    icon: root.tab === 0 ? Icons.speaker : Icons.microphone
                    title: modelData.description ?? modelData.nickname ?? modelData.name
                    selected: modelData === (root.tab === 0 ? Audio.sink : Audio.source)
                    onClicked: root.tab === 0 ? Audio.setDefaultSink(modelData) : Audio.setDefaultSource(modelData)

                    Text {
                        visible: deviceRow.selected
                        text: Icons.check
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsMd
                        color: Theme.green
                    }
                }
            }
        }

        // ── Application streams ─────────────────────────────────────────────
        Column {
            width: parent.width
            spacing: Theme.sp3
            visible: root.tab === 2

            Text {
                visible: Audio.streams.length === 0
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "Nothing is playing"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsSm
                color: Theme.muted
            }

            Repeater {
                model: Audio.streams

                delegate: Column {
                    required property PwNode modelData
                    width: parent.width
                    spacing: Theme.sp1

                    Item {
                        width: parent.width
                        height: 18

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 44
                            text: Audio.streamName(modelData)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsSm
                            color: Theme.text
                            elide: Text.ElideRight
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: `${Math.round((modelData.audio?.volume ?? 0) * 100)}%`
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsXs
                            color: Theme.muted
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.sp3

                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalPadding: 0
                            fontSize: Theme.fsMd
                            icon: Icons.volume(modelData.audio?.volume ?? 0, modelData.audio?.muted ?? false, "default")
                            colour: (modelData.audio?.muted ?? false) ? Theme.red : Theme.accentLight
                            onClicked: {
                                if (modelData.audio)
                                    modelData.audio.muted = !modelData.audio.muted;
                            }
                        }

                        StyledSlider {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 36
                            trackHeight: 5
                            knobSize: 13
                            value: modelData.audio?.volume ?? 0
                            enabled: !(modelData.audio?.muted ?? false)
                            fillColour: Theme.accentLight
                            onMoved: v => {
                                if (modelData.audio)
                                    modelData.audio.volume = v;
                            }
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
                label: "Sound settings"
                fontSize: Theme.fsMd
                colour: Theme.muted
                onClicked: {
                    Popouts.close();
                    Quickshell.execDetached(["pavucontrol"]);
                }
            }
        }
    }
}
