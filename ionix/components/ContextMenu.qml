// A themed popup menu built from a plain JavaScript model.
//
// TrayMenu covers the DBusMenu case, where a tray application publishes its menu
// over the bus and QsMenuOpener hands us the entries. Nothing publishes a menu for
// an ordinary application window, so the taskbar assembles one locally out of the
// app's desktop-entry actions and passes it here as an array.
//
// Entry shape (only `text` is required):
//   text       the label
//   icon       themed icon name, drawn in the leading slot
//   glyph      icon-font character, drawn in the leading slot when there's no icon
//   enabled    defaults to true
//   danger     draw in the error colour, for destructive entries
//   separator  a divider line; every other field is ignored
//   trigger    function run on activation
//
// `model` is assigned rather than bound. Desktop-entry actions are static, but a
// menu whose rows renumber under the pointer while it's open would be worse than
// one showing slightly stale contents, so callers freeze it at open time.
//
// There is no submenu support here: a desktop entry's actions are a flat list by
// specification. TrayMenu keeps the nesting machinery for the tray, which needs it.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.config

PopupWindow {
    id: root

    property var model: []
    property Item anchorItem: null
    property bool shouldOpen: false

    // Optional title row identifying what the menu acts on.
    property string headerText: ""
    property string headerIcon: ""

    // Emitted when the menu should go away: an entry was activated, Escape was
    // pressed, or the focus grab was cleared.
    signal dismissRequested

    readonly property var entries: root.model ?? []

    readonly property int menuPadding: Theme.sp2
    readonly property int rowHeight: 28
    readonly property int headerHeight: 32
    readonly property int leadingSize: 18
    readonly property int headerIconSize: 20

    readonly property bool hasHeader: root.headerText !== ""
    // Reserved menu-wide rather than per row, so labels line up in a column
    // instead of stepping in and out beside their icons.
    readonly property bool hasLeading: root.entries.some(e => !e.separator && (e.icon || e.glyph))

    readonly property int contentWidth: root.menuWidth - root.menuPadding * 2
    readonly property int menuWidth: Math.max(180, Math.min(420, measure.naturalWidth + root.menuPadding * 2))
    readonly property int maxHeight: Math.round((root.screen?.height ?? 1080) * 0.7)

    visible: root.shouldOpen
    color: "transparent"
    grabFocus: root.shouldOpen

    anchor.item: root.anchorItem
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.margins.top: Theme.sp2
    anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.FlipY

    implicitWidth: root.menuWidth
    implicitHeight: panel.implicitHeight

    HyprlandFocusGrab {
        active: root.shouldOpen
        windows: [root]
        onCleared: root.dismissRequested()
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.shouldOpen
        onActivated: root.dismissRequested()
    }

    // Off-screen width measurement.
    //
    // The menu can't size itself from the rows it displays: a positioner derives
    // its implicit width from its children's *widths*, and those rows are stretched
    // to the menu width, which would close the loop. These labels are unconstrained,
    // so the column's implicit width really is the widest label. Drawn at zero
    // opacity rather than visible:false, because a positioner ignores children that
    // aren't effectively visible.
    Item {
        id: measure

        readonly property int rowsWidth: labels.implicitWidth + (root.hasLeading ? root.leadingSize + Theme.sp3 : 0)
        readonly property int headerWidth: root.hasHeader ? headerLabel.implicitWidth + root.headerIconSize + Theme.sp3 : 0
        readonly property int naturalWidth: Theme.sp3 * 2 + Math.max(measure.rowsWidth, measure.headerWidth)

        opacity: 0
        enabled: false
        z: -1

        Column {
            id: labels

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
        }

        Text {
            id: headerLabel
            text: root.headerText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsMd
            font.weight: Font.DemiBold
        }
    }

    GlassPanel {
        id: panel
        width: root.menuWidth
        padding: root.menuPadding
        radius: Theme.rPill

        opacity: root.shouldOpen ? 1 : 0
        scale: root.shouldOpen ? 1 : 0.96
        transformOrigin: Item.Top

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

        Flickable {
            width: root.contentWidth
            height: Math.min(column.implicitHeight, root.maxHeight - root.menuPadding * 2)
            contentHeight: column.implicitHeight
            contentWidth: root.contentWidth
            interactive: contentHeight > height
            clip: interactive
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: column
                width: root.contentWidth

                Item {
                    visible: root.hasHeader
                    width: root.contentWidth
                    height: visible ? root.headerHeight : 0

                    IconImage {
                        id: headerImage
                        visible: root.headerIcon !== ""
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.sp3
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.headerIconSize
                        height: root.headerIconSize
                        source: root.headerIcon === "" ? "" : Quickshell.iconPath(root.headerIcon, true)
                        asynchronous: true
                    }

                    Text {
                        anchors.left: root.headerIcon !== "" ? headerImage.right : parent.left
                        anchors.leftMargin: Theme.sp3
                        anchors.right: parent.right
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
                    visible: root.hasHeader && root.entries.length > 0
                    width: root.contentWidth - Theme.sp3 * 2
                    x: Theme.sp3
                    height: visible ? 1 : 0
                    color: Theme.divider
                }

                // Spacing below the divider, so the first row isn't flush against it.
                Item {
                    visible: root.hasHeader
                    width: root.contentWidth
                    height: visible ? Theme.sp2 : 0
                }

                Repeater {
                    model: root.entries

                    delegate: Item {
                        id: entryRow

                        required property var modelData

                        readonly property bool isSeparator: entryRow.modelData.separator === true
                        readonly property bool actionable: !entryRow.isSeparator && entryRow.modelData.enabled !== false
                        // checkExists, because these names come from arbitrary
                        // .desktop files: the icon provider paints a missing-texture
                        // checkerboard for a name the theme doesn't have, so resolve
                        // it here and fall through to the glyph when it misses.
                        readonly property string iconSource: {
                            const name = entryRow.modelData.icon ?? "";
                            return name === "" ? "" : Quickshell.iconPath(name, true);
                        }
                        readonly property color labelColour: {
                            if (!entryRow.actionable)
                                return Theme.muted;
                            return entryRow.modelData.danger === true ? Theme.red : Theme.text;
                        }

                        width: root.contentWidth
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
                                // Dismiss first: launching can take long enough that a
                                // menu left on screen looks like the click missed.
                                root.dismissRequested();
                                if (typeof entryRow.modelData.trigger === "function")
                                    entryRow.modelData.trigger();
                            }
                        }
                    }
                }
            }
        }
    }
}
