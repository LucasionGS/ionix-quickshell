// Now playing: transport, album art, scrolling title.
//
// Collapses to zero width with an animation when nothing is playing, so it slides
// away rather than popping out of the layout.

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.components
import qs.popouts
import qs.services

Item {
    id: root

    property var bar: null
    readonly property bool popoutOpen: Popouts.isOpen("media", root.bar?.screen)
    readonly property bool hasArt: Player.artUrl !== ""

    visible: Config.media.backend !== "off"
    implicitWidth: Player.active ? pill.implicitWidth : 0
    implicitHeight: Theme.pillHeight
    clip: implicitWidth < pill.implicitWidth

    opacity: Player.active ? 1 : 0

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Theme.durSlide
            easing.type: Theme.easeStandard
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durNormal
        }
    }

    Pill {
        id: pill
        height: parent.height
        accented: Player.playing
        padding: Theme.sp2
        spacing: Theme.sp1

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: Icons.prev
            fontSize: Theme.fsMd
            colour: Theme.muted
            hoverColour: Theme.accentLight
            horizontalPadding: Theme.sp2
            tooltip: "Previous"
            onClicked: Player.previous()
        }

        // ── Art or equalizer ────────────────────────────────────────────────
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 22

            ClippingRectangle {
                anchors.fill: parent
                visible: root.hasArt
                radius: 5
                color: Theme.bgDeep

                Image {
                    anchors.fill: parent
                    source: Player.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                }
            }

            // No art: three bars that dance while playing and rest when paused.
            // Cheaper than it looks and it makes "is this playing?" obvious.
            Row {
                anchors.centerIn: parent
                visible: !root.hasArt
                spacing: 2

                Repeater {
                    model: 3

                    delegate: Rectangle {
                        required property int index
                        width: 3
                        radius: 1.5
                        color: Player.playing ? Theme.accentBright : Theme.muted
                        height: Player.playing ? 4 : 8
                        anchors.verticalCenter: parent.verticalCenter

                        SequentialAnimation on height {
                            running: Player.playing
                            loops: Animation.Infinite
                            alwaysRunToEnd: false
                            PauseAnimation {
                                duration: index * 130
                            }
                            NumberAnimation {
                                to: 14
                                duration: 380
                                easing.type: Easing.InOutSine
                            }
                            NumberAnimation {
                                to: 4
                                duration: 380
                                easing.type: Easing.InOutSine
                            }
                        }
                    }
                }
            }
        }

        // ── Title / artist ──────────────────────────────────────────────────
        Item {
            id: labelArea
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(Config.media.maxWidth, Math.max(titleText.implicitWidth, artistText.implicitWidth))
            height: Theme.pillHeight - 12
            clip: true

            Column {
                id: labels
                width: parent.width
                anchors.verticalCenter: parent.verticalCenter
                spacing: -1

                // Marquee: only animates when the text is actually too long, and
                // dwells at each end so it's readable rather than a constant crawl.
                Item {
                    width: parent.width
                    height: titleText.implicitHeight

                    Text {
                        id: titleText
                        text: Player.title !== "" ? Player.title : Player.identity
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsMd
                        color: Theme.text

                        readonly property bool overflowing: implicitWidth > labelArea.width

                        SequentialAnimation on x {
                            running: titleText.overflowing
                            loops: Animation.Infinite
                            alwaysRunToEnd: false
                            PauseAnimation {
                                duration: 1500
                            }
                            NumberAnimation {
                                to: labelArea.width - titleText.implicitWidth
                                duration: Math.max(1200, (titleText.implicitWidth - labelArea.width) * 22)
                                easing.type: Easing.InOutQuad
                            }
                            PauseAnimation {
                                duration: 1500
                            }
                            NumberAnimation {
                                to: 0
                                duration: Math.max(1200, (titleText.implicitWidth - labelArea.width) * 22)
                                easing.type: Easing.InOutQuad
                            }
                        }

                        onOverflowingChanged: if (!overflowing)
                            x = 0
                    }
                }

                Text {
                    id: artistText
                    width: parent.width
                    visible: Player.artist !== ""
                    text: Player.artist
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsXs
                    color: Theme.muted
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Popouts.toggle("media", root.bar?.screen)
                onWheel: event => {
                    // Player volume where supported, otherwise scrub.
                    if (Player.canSetVolume)
                        Player.setVolume((Player.player?.volume ?? 0) + (event.angleDelta.y > 0 ? 0.05 : -0.05));
                    else
                        Player.seek(event.angleDelta.y > 0 ? 5 : -5);
                    event.accepted = true;
                }
            }
        }

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: Player.playing ? Icons.pause : Icons.play
            fontSize: Theme.fsIcon
            colour: Player.playing ? Theme.accentBright : Theme.text
            hoverColour: Theme.textBright
            horizontalPadding: Theme.sp2
            tooltip: Player.playing ? "Pause" : "Play"
            onClicked: Player.toggle()
        }

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: Icons.next
            fontSize: Theme.fsMd
            colour: Theme.muted
            hoverColour: Theme.accentLight
            horizontalPadding: Theme.sp2
            tooltip: "Next"
            onClicked: Player.next()
        }
    }

    MediaPopout {
        anchorItem: root
        shouldOpen: root.popoutOpen
    }
}
