// One window in the Alt+Tab switcher: a live thumbnail with an icon footer.
//
// First use of ScreencopyView in this tree. Two things learned the hard way
// elsewhere and designed for here rather than discovered later: the capture
// source must be the wlr-foreign-toplevel handle (`toplevel.wayland`), not the
// HyprlandToplevel wrapper; and Hyprland's toplevel export routinely has no
// frame to give for windows on inactive workspaces, so the icon fallback is a
// first-class path (gated on `hasContent`), not an error state.
//
// Kept in components/ rather than osd/ so a future taskbar hover-preview can
// reuse it.

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.config
import qs.services

Item {
    id: root

    property var toplevel: null
    property bool selected: false
    readonly property bool hovered: mouse.containsMouse

    signal activated

    width: Config.windowSwitcher.cardWidth
    height: Config.windowSwitcher.cardHeight

    // Optional-chained everywhere: the toplevel can be destroyed a frame before
    // the session prunes it out of the model.
    readonly property string iconName: Windows.iconFor(root.toplevel)
    readonly property string label: root.toplevel?.title ?? Windows.appId(root.toplevel)
    // Through the service, not toplevel.urgent — see WindowSwitcher's urgency
    // tracking for why the property alone cannot be trusted.
    readonly property bool urgent: WindowSwitcher.isUrgent(root.toplevel)

    // Surround glow on an urgent card — the border alone reads like a hover
    // state at a glance; a halo singles the card out across a full grid.
    // Sibling of the card, not a child: a Rectangle paints its own fill before
    // any child, so a shadow parented to it could never sit behind it.
    RectangularShadow {
        anchors.fill: parent
        radius: Theme.rPill
        blur: 28
        spread: 3
        offset: Qt.vector2d(0, 0)
        color: Theme.alpha(Theme.orange, 0.55)
        opacity: root.urgent ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durNormal
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.rPill
        color: root.selected ? Theme.alpha(Theme.accentBright, 0.16) : (root.hovered ? Theme.alpha(Theme.hover, 0.5) : Theme.alpha(Theme.bgCard, 0.35))
        border.width: root.selected ? 2 : 1
        // Urgent windows are preselected by the service; the orange border says
        // why this card, of all of them, is the one the highlight opened on.
        border.color: root.selected ? Theme.accentBright : (root.urgent ? Theme.alpha(Theme.orange, 0.7) : Theme.pillBorder)

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
        clip: true

        ScreencopyView {
            id: shot
            // Letterboxed by hand from sourceSize — the view scales its frame to
            // the item's bounds, so sizing it to the box would stretch aspect.
            readonly property real fit: (sourceSize.width > 0 && sourceSize.height > 0) ? Math.min(thumbBox.width / sourceSize.width, thumbBox.height / sourceSize.height) : 0
            anchors.centerIn: parent
            width: Math.max(1, Math.floor(sourceSize.width * fit))
            height: Math.max(1, Math.floor(sourceSize.height * fit))
            captureSource: root.toplevel?.wayland ?? null
            // Every visible card is one continuous capture stream, which is why
            // this stops with the overlay and why livePreviews exists at all.
            live: root.visible && Config.windowSwitcher.livePreviews
            constraintSize: Qt.size(thumbBox.width, thumbBox.height)
            visible: hasContent
        }

        // No frame available (other-workspace window, previews disabled): the
        // taskbar's placeholder recipe at thumbnail scale.
        Item {
            anchors.fill: parent
            visible: !shot.hasContent

            IconImage {
                anchors.centerIn: parent
                visible: root.iconName !== ""
                width: 48
                height: 48
                source: root.iconName === "" ? "" : Quickshell.iconPath(root.iconName)
                asynchronous: true
            }

            Rectangle {
                anchors.centerIn: parent
                visible: root.iconName === ""
                width: 48
                height: 48
                radius: Theme.rSm
                color: Theme.alpha(Theme.accentBright, 0.18)

                Text {
                    anchors.centerIn: parent
                    text: (Windows.appId(root.toplevel) || "?").charAt(0).toUpperCase()
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsTitle
                    font.weight: Font.Bold
                    color: Theme.accentLight
                }
            }
        }
    }

    Row {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.sp3
        height: 18
        spacing: Theme.sp2

        IconImage {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.iconName !== ""
            width: 16
            height: 16
            source: root.iconName === "" ? "" : Quickshell.iconPath(root.iconName)
            asynchronous: true
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - (root.iconName !== "" ? 16 + Theme.sp2 : 0)
            text: root.label
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsSm
            color: root.selected || root.hovered ? Theme.textBright : Theme.text
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
