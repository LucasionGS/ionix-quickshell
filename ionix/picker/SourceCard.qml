// One thing the share picker can share: a monitor or a window, as a preview
// over a title line.
//
// `WindowPreviewCard`'s recipe (letterboxed ScreencopyView, icon fallback for
// windows that have no frame on a hidden workspace), widened to take a screen
// as its source. `live: false` keeps the first frame: the picker's own monitor
// is shown that way, because a live copy of it would show the picker inside
// itself.

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.config

Item {
    id: root

    // A ShellScreen or a wlr-foreign-toplevel handle (`HyprlandToplevel.wayland`).
    property var source: null
    property bool live: true
    property string title: ""
    property string subtitle: ""
    // Over the preview's top-left corner: "This screen", a desktop's name.
    property string chip: ""
    property string iconName: ""
    // Drawn when there is no icon and no frame either.
    property string glyph: ""
    property bool selected: false
    readonly property bool hovered: mouse.containsMouse
    readonly property bool hasFrame: shot.hasContent

    signal clicked
    signal doubleClicked

    Rectangle {
        anchors.fill: parent
        radius: Theme.rPill
        color: root.selected ? (Theme.flat ? Theme.subtleHover : Theme.alpha(Theme.accentBright, 0.16)) : (root.hovered ? Theme.alpha(Theme.hover, 0.5) : Theme.alpha(Theme.bgCard, 0.35))
        border.width: root.selected ? 2 : 1
        border.color: root.selected ? (Theme.flat ? Theme.textBright : Theme.accentBright) : Theme.pillBorder

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
    }

    Item {
        id: thumbBox
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footer.top
        anchors.margins: Theme.sp3
        anchors.bottomMargin: Theme.sp2
        clip: true

        Rectangle {
            anchors.fill: parent
            radius: Theme.rSm
            color: Theme.alpha(Theme.bgDeep, 0.45)
        }

        ScreencopyView {
            id: shot
            // Sized from the frame rather than to the box, which would stretch it.
            readonly property real fit: (sourceSize.width > 0 && sourceSize.height > 0) ? Math.min(thumbBox.width / sourceSize.width, thumbBox.height / sourceSize.height) : 0
            anchors.centerIn: parent
            width: Math.max(1, Math.floor(sourceSize.width * fit))
            height: Math.max(1, Math.floor(sourceSize.height * fit))
            captureSource: root.source
            live: root.live
            constraintSize: Qt.size(thumbBox.width, thumbBox.height)
            visible: hasContent
        }

        Item {
            anchors.fill: parent
            visible: !shot.hasContent

            IconImage {
                anchors.centerIn: parent
                visible: root.iconName !== ""
                width: 48
                height: 48
                source: root.iconName === "" ? "" : Quickshell.iconPath(root.iconName, "application-x-executable")
                asynchronous: true
            }

            Text {
                anchors.centerIn: parent
                visible: root.iconName === ""
                text: root.glyph !== "" ? root.glyph : (root.title || "?").charAt(0).toUpperCase()
                font.family: Theme.fontFamily
                font.pixelSize: 40
                color: Theme.alpha(Theme.accentLight, 0.8)
            }
        }

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: Theme.sp2
            visible: root.chip !== ""
            width: Math.min(chipText.implicitWidth + Theme.sp3 * 2, thumbBox.width - Theme.sp2 * 2)
            height: 20
            radius: Theme.rRound
            color: Theme.alpha(Theme.bgDeep, 0.8)
            border.width: 1
            border.color: Theme.alpha(Theme.accentBright, 0.45)

            Text {
                id: chipText
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - Theme.sp3 * 2)
                text: root.chip
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsXs
                font.weight: Font.DemiBold
                color: Theme.textBright
            }
        }
    }

    Row {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.sp3
        height: 34
        spacing: Theme.sp3

        IconImage {
            id: footIcon
            anchors.verticalCenter: parent.verticalCenter
            visible: root.iconName !== ""
            width: 20
            height: 20
            source: root.iconName === "" ? "" : Quickshell.iconPath(root.iconName, "application-x-executable")
            asynchronous: true
        }

        Text {
            id: footGlyph
            anchors.verticalCenter: parent.verticalCenter
            visible: root.iconName === "" && root.glyph !== ""
            text: root.glyph
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsIconLg
            color: root.selected ? Theme.accentLight : Theme.text
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - (footIcon.visible ? footIcon.width + parent.spacing : 0) - (footGlyph.visible ? footGlyph.implicitWidth + parent.spacing : 0)
            spacing: 0

            Text {
                width: parent.width
                text: root.title
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsBase
                font.weight: Font.DemiBold
                color: root.selected || root.hovered ? Theme.textBright : Theme.text
            }

            Text {
                width: parent.width
                visible: root.subtitle !== ""
                text: root.subtitle
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsSm
                color: Theme.muted
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        onDoubleClicked: root.doubleClicked()
    }
}
