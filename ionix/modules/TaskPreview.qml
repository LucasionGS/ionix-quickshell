// The thumbnails over a taskbar or dock button: one card per window of that app, with
// its title and a close button, live for as long as the pointer stays.
//
// Not a Popout: it must not take focus or a grab, or merely pointing at the bar
// would close whatever flyout is open and steal the keyboard from the window you
// are typing in.

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

PopupWindow {
    id: root

    property Item anchorItem: null
    property bool shouldOpen: false
    property var windows: []
    // Which way it opens, for a host that is not on the bar. -1 goes away from the bar.
    property int edge: -1
    // Further clear of the anchor, for one with something drawn past its bounds.
    property int extraGap: 0

    signal entered
    signal exited
    signal dismissed

    readonly property int cardWidth: 200
    readonly property int cardHeight: 130

    visible: root.shouldOpen
    color: "transparent"

    anchor.item: root.anchorItem
    // Away from the bar, whichever edge it is on.
    readonly property int openEdge: {
        if (root.edge !== -1)
            return root.edge;
        if (Config.barVertical)
            return Config.barPopupEdge;
        return Config.bar.position === "bottom" ? Edges.Top : Edges.Bottom;
    }
    readonly property int gap: (Theme.flyoutGap > 0 ? Theme.flyoutGap : Theme.sp2) + root.extraGap
    anchor.edges: root.openEdge
    anchor.gravity: root.openEdge
    anchor.adjustment: root.openEdge === Edges.Left || root.openEdge === Edges.Right ? PopupAdjustment.SlideY : PopupAdjustment.SlideX
    // The rect rather than margins: a margin on the far side of the rect does not move
    // the edge the panel hangs from, so an upward panel would ignore it.
    anchor.rect.x: root.openEdge === Edges.Left ? -root.gap : (root.openEdge === Edges.Right ? root.gap : 0)
    anchor.rect.y: root.openEdge === Edges.Top ? -root.gap : (root.openEdge === Edges.Bottom ? root.gap : 0)
    anchor.rect.width: root.anchorItem?.width ?? 0
    anchor.rect.height: root.anchorItem?.height ?? 0

    implicitWidth: row.implicitWidth + Theme.sp3 * 2
    implicitHeight: root.cardHeight + Theme.sp3 * 2

    GlassPanel {
        anchors.fill: parent
        padding: 0
    }

    HoverHandler {
        onHoveredChanged: hovered ? root.entered() : root.exited()
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.sp2

        Repeater {
            model: root.windows

            delegate: Item {
                id: card
                required property var modelData

                width: root.cardWidth
                height: root.cardHeight

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.rSm
                    color: cardMouse.containsMouse ? Theme.subtleHover : "transparent"
                }

                // Title row.
                Text {
                    x: Theme.sp3
                    y: Theme.sp2
                    width: parent.width - Theme.sp3 - closeButton.width - Theme.sp2
                    text: card.modelData.title ?? ""
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsSm
                    color: Theme.textBright
                }

                ClippingRectangle {
                    x: Theme.sp3
                    y: 28
                    width: parent.width - Theme.sp3 * 2
                    height: parent.height - 28 - Theme.sp3
                    radius: Theme.rSm
                    color: "transparent"

                    ScreencopyView {
                        anchors.fill: parent
                        captureSource: root.shouldOpen ? (card.modelData.wayland ?? null) : null
                        live: true
                    }
                }

                MouseArea {
                    id: cardMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        Windows.activate(card.modelData);
                        root.dismissed();
                    }
                }

                // Above the card's own MouseArea, which would otherwise take the click.
                Rectangle {
                    id: closeButton
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 2
                    width: 24
                    height: 24
                    radius: Theme.rSm
                    visible: cardMouse.containsMouse || closeMouse.containsMouse
                    color: closeMouse.containsMouse ? Theme.closeHover : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: Icons.close
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsSm
                        color: Theme.textBright
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: Windows.close(card.modelData)
                    }
                }
            }
        }
    }
}
