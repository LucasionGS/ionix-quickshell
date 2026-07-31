// A context menu drawn inside its parent panel rather than in a window of its own.
//
// ContextMenu is the right thing when the menu comes off a bar item: it is a
// PopupWindow, so it can extend past the surface that spawned it. That does not
// survive a second level of nesting — a popup anchored to an item that is itself
// inside a PopupWindow maps, reports a size and a screen, and then never
// composites. So a menu raised from inside a panel is drawn as an overlay on that
// panel instead, which also spares the caller a second focus grab to arbitrate.
//
// The entry model is identical to ContextMenu's, plus one flag:
//   text · icon · glyph · enabled · danger · separator · trigger · keepOpen
// keepOpen leaves the menu up after activation, for entries meant to be used more
// than once in a row — reordering a pinned tile, say.
//
// Fill the area the menu may cover (usually the whole panel) and give it a point
// to open at; it clamps itself to stay inside.

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.config

Item {
    id: root

    property var model: []
    property bool open: false
    property string headerText: ""
    // Where the menu's top-left wants to be, in this item's coordinates.
    property real originX: 0
    property real originY: 0

    signal dismissed

    readonly property var entries: root.model ?? []
    readonly property bool hasLeading: root.entries.some(e => !e.separator && (e.icon || e.glyph))

    readonly property int menuPadding: Theme.sp2
    readonly property int rowHeight: 28
    readonly property int leadingSize: 18

    readonly property int menuWidth: Math.max(170, Math.min(360, measure.implicitWidth + (root.hasLeading ? root.leadingSize + Theme.sp3 : 0) + Theme.sp3 * 2 + root.menuPadding * 2))

    visible: root.open

    // Swallows every click that is not on a row, which is what dismisses the menu.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: root.dismissed()
    }

    // Off-screen width measurement: rows are stretched to the menu width, so the
    // menu cannot size itself from them without closing the loop. These labels are
    // unconstrained. Zero opacity rather than invisible, because a positioner skips
    // children that aren't effectively visible.
    Column {
        id: measure
        opacity: 0
        enabled: false
        z: -1

        Repeater {
            model: root.entries

            delegate: Text {
                required property var modelData

                visible: !modelData.separator
                text: modelData.text ?? ""
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsMd
            }
        }

        Text {
            text: root.headerText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsMd
            font.weight: Font.DemiBold
        }
    }

    Item {
        id: menu

        x: Math.max(0, Math.min(root.originX, root.width - width))
        y: Math.max(0, Math.min(root.originY, root.height - height))
        width: root.menuWidth
        height: column.implicitHeight + root.menuPadding * 2

        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.96
        transformOrigin: Item.TopLeft

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durFast
                easing.type: Theme.easeStandard
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Theme.durFast
                easing.type: Theme.easeStandard
            }
        }

        RectangularShadow {
            anchors.fill: bg
            radius: bg.radius
            blur: 32
            spread: 0
            offset: Qt.vector2d(0, 8)
            color: Qt.rgba(0, 0, 0, 0.6)
        }

        // Near-opaque: this floats over an already translucent panel, and stacking
        // two glass layers makes the labels unreadable.
        Rectangle {
            id: bg
            anchors.fill: parent
            radius: Theme.rPill
            color: Theme.alpha(Theme.bgDeep, 0.97)
            border.width: 1
            border.color: Theme.panelBorder
        }

        Column {
            id: column
            x: root.menuPadding
            y: root.menuPadding
            width: menu.width - root.menuPadding * 2

            Item {
                visible: root.headerText !== ""
                width: parent.width
                height: visible ? 30 : 0

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: Theme.sp3
                    anchors.rightMargin: Theme.sp3
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.headerText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMd
                    font.weight: Font.DemiBold
                    color: Theme.textBright
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                visible: root.headerText !== "" && root.entries.length > 0
                x: Theme.sp3
                width: parent.width - Theme.sp3 * 2
                height: visible ? 1 : 0
                color: Theme.divider
            }

            Item {
                visible: root.headerText !== ""
                width: parent.width
                height: visible ? Theme.sp2 : 0
            }

            Repeater {
                model: root.entries

                delegate: Item {
                    id: entryRow
                    required property var modelData

                    readonly property bool isSeparator: entryRow.modelData.separator === true
                    readonly property bool actionable: !entryRow.isSeparator && entryRow.modelData.enabled !== false
                    // checkExists, because these names come from arbitrary .desktop
                    // files and the icon provider paints a missing-texture
                    // checkerboard for a name the theme doesn't have.
                    readonly property string iconSource: {
                        const name = entryRow.modelData.icon ?? "";
                        return name === "" ? "" : Quickshell.iconPath(name, true);
                    }
                    readonly property color labelColour: {
                        if (!entryRow.actionable)
                            return Theme.muted;
                        return entryRow.modelData.danger === true ? Theme.red : Theme.text;
                    }

                    width: parent.width
                    height: entryRow.isSeparator ? Theme.sp2 * 2 + 1 : root.rowHeight

                    Rectangle {
                        visible: entryRow.isSeparator
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Theme.sp3
                        anchors.rightMargin: Theme.sp3
                        height: 1
                        color: Theme.divider
                    }

                    Rectangle {
                        visible: !entryRow.isSeparator
                        anchors.fill: parent
                        radius: Theme.rSm
                        color: (entryRow.actionable && rowMouse.containsMouse) ? Theme.alpha(entryRow.modelData.danger === true ? Theme.red : Theme.hover, 0.7) : "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.durFast
                            }
                        }
                    }

                    Item {
                        id: leading
                        visible: !entryRow.isSeparator && root.hasLeading
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.sp3
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.leadingSize
                        height: root.leadingSize

                        IconImage {
                            anchors.fill: parent
                            visible: entryRow.iconSource !== ""
                            source: entryRow.iconSource
                            asynchronous: true
                            opacity: entryRow.actionable ? 1 : 0.4
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: entryRow.iconSource === "" && (entryRow.modelData.glyph ?? "") !== ""
                            text: entryRow.modelData.glyph ?? ""
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsMd
                            color: entryRow.labelColour
                        }
                    }

                    Text {
                        visible: !entryRow.isSeparator
                        anchors.left: root.hasLeading ? leading.right : parent.left
                        anchors.leftMargin: Theme.sp3
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.sp3
                        anchors.verticalCenter: parent.verticalCenter
                        text: entryRow.modelData.text ?? ""
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsMd
                        color: entryRow.labelColour
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        enabled: !entryRow.isSeparator
                        hoverEnabled: true
                        cursorShape: entryRow.actionable ? Qt.PointingHandCursor : Qt.ArrowCursor

                        onClicked: {
                            if (!entryRow.actionable)
                                return;
                            if (typeof entryRow.modelData.trigger === "function")
                                entryRow.modelData.trigger();
                            if (entryRow.modelData.keepOpen !== true)
                                root.dismissed();
                        }
                    }
                }
            }
        }
    }
}
