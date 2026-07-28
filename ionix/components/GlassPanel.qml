// The body of every popout: translucent tinted fill, accent border, drop shadow.
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
