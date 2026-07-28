// Now playing, expanded: art, seek bar, transport, player picker.
//
// The panel tints itself with a blurred copy of the album art. It's the single
// highest-payoff detail in the shell — the popout picks up the colour of whatever
// is playing without any palette extraction.

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

Popout {
    id: root

    panelWidth: 360
    readonly property bool hasArt: Player.artUrl !== ""

    // Art-derived backdrop, clipped to the panel's rounded shape.
    ClippingRectangle {
        anchors.fill: parent
        anchors.margins: -root.padding
        radius: Theme.rPanel
        color: "transparent"
        visible: root.hasArt
        z: -1

        Image {
            id: backdropSource
            anchors.fill: parent
            source: Player.artUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: backdropSource
            blurEnabled: true
            blur: 1.0
            blurMax: 64
            saturation: 0.4
            opacity: 0.25
        }
    }

    Column {
        width: parent.width
        spacing: Theme.sp4

        // ── Art + metadata ──────────────────────────────────────────────────
        Row {
            width: parent.width
            spacing: Theme.sp4

            ClippingRectangle {
                width: 96
                height: 96
                radius: Theme.rPill
                color: Theme.alpha(Theme.bgDeep, 0.8)

                Image {
                    anchors.fill: parent
                    visible: root.hasArt
                    source: Player.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                Text {
                    anchors.centerIn: parent
                    visible: !root.hasArt
                    text: Icons.music
                    font.family: Theme.fontFamily
                    font.pixelSize: 40
                    color: Theme.border
                }
            }

            Column {
                width: parent.width - 96 - Theme.sp4
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.sp1

                Text {
                    width: parent.width
                    text: Player.title !== "" ? Player.title : "Nothing playing"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsLg
                    font.weight: Font.DemiBold
                    color: Theme.textBright
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                }

                Text {
                    width: parent.width
                    visible: Player.artist !== ""
                    text: Player.artist
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMd
                    color: Theme.text
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    visible: Player.album !== ""
                    text: Player.album
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsSm
                    color: Theme.muted
                    elide: Text.ElideRight
                }
            }
        }

        // ── Seek ────────────────────────────────────────────────────────────
        Column {
            width: parent.width
            spacing: Theme.sp1
            visible: Player.length > 0

            StyledSlider {
                width: parent.width
                trackHeight: 5
                knobSize: 13
                enabled: Player.canSeek
                value: Player.length > 0 ? Player.position / Player.length : 0
                onMoved: v => Player.seekTo(v)
            }

            Item {
                width: parent.width
                height: 14

                Text {
                    anchors.left: parent.left
                    text: Player.formatTime(Player.position)
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fsXs
                    color: Theme.muted
                }

                Text {
                    anchors.right: parent.right
                    text: Player.formatTime(Player.length)
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fsXs
                    color: Theme.muted
                }
            }
        }

        // ── Transport ───────────────────────────────────────────────────────
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.sp3

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: Player.player?.shuffleSupported ?? false
                icon: (Player.player?.shuffle ?? false) ? Icons.shuffleOn : Icons.shuffle
                colour: (Player.player?.shuffle ?? false) ? Theme.accentBright : Theme.muted
                tooltip: "Shuffle"
                onClicked: {
                    if (Player.player)
                        Player.player.shuffle = !Player.player.shuffle;
                }
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: Icons.prev
                fontSize: Theme.fsIconLg
                colour: Theme.text
                tooltip: "Previous"
                onClicked: Player.previous()
            }

            // Play/pause gets a filled circle so it reads as the primary action.
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 44
                radius: 22
                color: playMouse.containsMouse ? Theme.accentBright : Theme.alpha(Theme.accentBright, 0.85)
                scale: playMouse.pressed ? 0.94 : 1.0

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durNormal
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.durFast
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: Player.playing ? Icons.pause : Icons.play
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsIconLg
                    color: Theme.bgDeep
                }

                MouseArea {
                    id: playMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Player.toggle()
                }
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: Icons.next
                fontSize: Theme.fsIconLg
                colour: Theme.text
                tooltip: "Next"
                onClicked: Player.next()
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: Player.player?.loopSupported ?? false
                icon: {
                    const state = Player.player?.loopState;
                    if (state === MprisLoopState.Track)
                        return Icons.loopTrack;
                    if (state === MprisLoopState.Playlist)
                        return Icons.loopList;
                    return Icons.loopNone;
                }
                colour: (Player.player?.loopState ?? MprisLoopState.None) !== MprisLoopState.None ? Theme.accentBright : Theme.muted
                tooltip: "Repeat"
                onClicked: {
                    if (!Player.player)
                        return;
                    const state = Player.player.loopState;
                    if (state === MprisLoopState.None)
                        Player.player.loopState = MprisLoopState.Playlist;
                    else if (state === MprisLoopState.Playlist)
                        Player.player.loopState = MprisLoopState.Track;
                    else
                        Player.player.loopState = MprisLoopState.None;
                }
            }
        }

        // ── Player volume ───────────────────────────────────────────────────
        Row {
            width: parent.width
            spacing: Theme.sp3
            visible: Player.canSetVolume

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                horizontalPadding: 0
                fontSize: Theme.fsMd
                icon: Icons.volume(Player.player?.volume ?? 0, false, "default")
                colour: Theme.accentLight
            }

            StyledSlider {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 32
                trackHeight: 5
                knobSize: 13
                value: Player.player?.volume ?? 0
                onMoved: v => Player.setVolume(v)
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.divider
            visible: Player.players.length > 1
        }

        // ── Player picker ───────────────────────────────────────────────────
        Column {
            width: parent.width
            spacing: 2
            visible: Player.players.length > 1

            Repeater {
                model: Player.players

                delegate: ListRow {
                    id: playerRow
                    required property MprisPlayer modelData

                    width: parent.width
                    icon: modelData.isPlaying ? Icons.play : Icons.pause
                    title: modelData.identity ?? modelData.dbusName
                    subtitle: modelData.trackTitle ?? ""
                    selected: modelData === Player.player
                    onClicked: Player.selected = playerRow.modelData
                }
            }
        }
    }
}
