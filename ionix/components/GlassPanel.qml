// The body of every popout: translucent tinted fill, accent border, drop shadow.
//
// `backdrop` optionally covers the fill with a picture, cropped to fill the panel
// whatever its aspect and darkened by `backdropDim` so the content on top stays
// readable. The border is drawn outside it, so the panel keeps its edge.
//
// Sizing: the caller sets `width` (popouts use a fixed panel width) and the height
// follows the content. `inner` is positioned rather than anchored, and measures
// itself with childrenRect — an Item with anchors.fill has an implicit size of
// zero, which would collapse the panel to just its padding.

import QtQuick
import QtQuick.Effects
import qs.config

Item {
    id: root

    default property alias content: inner.data
    property int padding: Theme.sp6
    property alias radius: bg.radius
    property color fill: Theme.panelFill
    property url backdrop: ""
    // Opacity of the bgDeep wash over the backdrop: 0 shows the picture as is.
    property real backdropDim: 0.55

    implicitWidth: inner.childrenRect.width + padding * 2
    implicitHeight: inner.childrenRect.height + padding * 2

    // Drawn behind the fill so the shadow doesn't wash out the border.
    RectangularShadow {
        anchors.fill: bg
        radius: bg.radius
        blur: 48
        spread: 0
        offset: Qt.vector2d(0, 12)
        color: Qt.rgba(0, 0, 0, 0.7)
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Theme.rPanel
        color: root.fill
        border.width: 1
        border.color: Theme.panelBorder
    }

    // Inset by the border's width and masked to the inner radius, so the picture
    // sits inside the border rather than over it.
    Item {
        id: backdrop
        anchors.fill: bg
        anchors.margins: bg.border.width
        visible: root.backdrop.toString() !== ""
        opacity: backdropImage.status === Image.Ready ? 1 : 0
        layer.enabled: backdrop.visible
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: backdropMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durNormal
            }
        }

        Image {
            id: backdropImage
            anchors.fill: parent
            source: root.backdrop
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            // Not cached, so a picture replaced under the same name shows up on
            // the next open rather than after a restart.
            cache: false
            // Decoded at a fixed box rather than the panel's size: a panel whose
            // height follows its content would otherwise re-decode the picture
            // every time a list inside it grew. 2x covers HiDPI and panels up to
            // twice as tall as they are wide.
            sourceSize: Qt.size(Math.ceil(root.width * 2), Math.ceil(root.width * 4))
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.alpha(Theme.bgDeep, root.backdropDim)
        }
    }

    Item {
        id: backdropMask
        anchors.fill: backdrop
        visible: false
        layer.enabled: backdrop.visible

        Rectangle {
            anchors.fill: parent
            radius: Math.max(0, bg.radius - bg.border.width)
            color: "black"
        }
    }

    // A one-pixel inner highlight along the top edge — cheap, and it stops the
    // panel reading as a flat rectangle against a dark wallpaper.
    Rectangle {
        anchors.top: bg.top
        anchors.left: bg.left
        anchors.right: bg.right
        anchors.margins: 1
        height: 1
        color: Qt.rgba(1, 1, 1, 0.04)
    }

    // Only the width is bound; binding height to childrenRect as well would loop
    // through any child that sizes off its parent. Content is laid out top-down,
    // so inner's own height is never read.
    Item {
        id: inner
        x: root.padding
        y: root.padding
        width: root.width - root.padding * 2
    }
}
