// Volume glyph with a level bar along the bottom edge.
//
// Scroll writes the Pipewire node volume directly rather than shelling out to
// wpctl — instant, exact, and no process per scroll tick.

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.popouts
import qs.services

Item {
    id: root

    property var bar: null
    readonly property bool popoutOpen: Popouts.isOpen("audio", root.bar?.screen)
    readonly property real level: Math.min(1, Audio.volume / Math.max(0.01, Audio.maxVolume))

    implicitWidth: button.implicitWidth
    implicitHeight: Theme.pillHeight

    IconButton {
        id: button
        anchors.fill: parent
        icon: Icons.volume(Audio.volume, Audio.muted, Audio.portType)
        colour: Audio.muted ? Theme.border : Theme.red
        hoverColour: Audio.muted ? Theme.muted : Theme.textBright
        active: root.popoutOpen
        tooltip: Audio.muted ? `Muted  ·  ${Audio.description}` : `${Math.round(Audio.volume * 100)}%  ·  ${Audio.description}`

        onClicked: Popouts.toggle("audio", root.bar?.screen)
        onMiddleClicked: Audio.toggleMute()
        onRightClicked: Quickshell.execDetached(["pavucontrol"])
        onScrolled: direction => Audio.stepVolume(direction)

        // Level bar, hidden when muted so "muted" and "zero volume" don't look alike.
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - Theme.sp4
            height: 2
            radius: 1
            color: Theme.alpha(Theme.border, 0.4)
            visible: !Audio.muted

            Rectangle {
                width: parent.width * root.level
                height: parent.height
                radius: parent.radius
                color: Theme.accentBright

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.durFast
                    }
                }
            }
        }
    }

    // Any volume change — from here, a media key, or another app — raises the OSD.
    Connections {
        target: Audio
        function onVolumeChanged() {
            Osd.showVolume(Audio.volume, Audio.muted);
        }
        function onMutedChanged() {
            Osd.showVolume(Audio.volume, Audio.muted);
        }
    }

    AudioPopout {
        anchorItem: root
        shouldOpen: root.popoutOpen
    }
}
