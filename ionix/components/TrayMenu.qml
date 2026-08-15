// One level of a StatusNotifierItem's DBusMenu, drawn in the Ionix theme.
//
// QsMenuAnchor renders the same menu, but as an unstyled platform menu that looks
// nothing like the rest of the shell. QsMenuOpener instead hands us the entries as
// a model, so we lay them out ourselves.
//
// Submenus are separate PopupWindows of this same type, loaded through a Loader
// with a source URL — QML rejects a component that names itself directly. Each
// level tracks the level below it in `windowChain`, and only the topmost menu
// installs a HyprlandFocusGrab, covering the whole chain so moving from a parent
// into a submenu doesn't dismiss everything.
//
// The opener's `menu` is only bound while the menu is open: constructing a
// QsMenuOpener sends AboutToShow to the owning application, and we don't want to
// poke every tray app on every reload.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.config
import qs.services

PopupWindow {
    id: root

    // QsMenuHandle — either SystemTrayItem.menu or a QsMenuEntry with children.
    property var menuHandle: null
    property Item anchorItem: null
    property bool isSubmenu: false
    // The menu that owns the focus grab; submenus point at their ancestor.
    property var rootMenu: root
    property bool shouldOpen: false

    // Emitted when the whole chain should go away: an entry was activated, Escape
    // was pressed, or the focus grab was cleared. Always emitted on `rootMenu`.
    signal dismissRequested

    readonly property var entries: opener.children?.values ?? []

    readonly property int menuPadding: Theme.sp2
    readonly property int rowHeight: 28
    readonly property int leadingSize: 18
    // Reserved slots are menu-wide rather than per row, so labels line up in a
    // column instead of stepping in and out beside their icons.
    readonly property bool hasLeading: root.entries.some(e => !e.isSeparator && (e.icon !== "" || e.buttonType !== QsMenuButtonType.None))
    readonly property bool hasSubmenus: root.entries.some(e => !e.isSeparator && e.hasChildren)

    readonly property int contentWidth: root.menuWidth - root.menuPadding * 2
    readonly property int menuWidth: Math.max(180, Math.min(420, measure.naturalWidth + root.menuPadding * 2))
    readonly property int maxHeight: Math.round((root.screen?.height ?? 1080) * 0.7)

    // Every window in this menu and everything opened beneath it, so the grab
    // installed by the root covers submenus too.
    readonly property var windowChain: submenuLoader.item ? [root].concat(submenuLoader.item.windowChain) : [root]

    // Which entry's submenu is showing at this level, and the row it hangs off.
    property var openSubmenuEntry: null
    property Item openSubmenuAnchor: null

    // DBusMenu labels carry mnemonic markers that mean nothing without keyboard
    // menu traversal. Only strip a marker that starts a word — otherwise a literal
    // label like "backup_2024" would lose its underscore. Newlines are flattened
    // because rows are a fixed height and a clipboard manager will happily hand us
    // a multi-line entry.
    function labelText(raw) {
        return (raw ?? "").replace(/\s+/g, " ").trim().replace(/(^|\s)[_&](?=[^\s])/g, "$1");
    }

    function openSubmenu(entry, anchor) {
        submenuCloser.stop();
        root.openSubmenuEntry = entry;
        root.openSubmenuAnchor = anchor;
    }

    function closeSubmenu() {
        submenuCloser.stop();
        root.openSubmenuEntry = null;
        root.openSubmenuAnchor = null;
    }

    visible: root.shouldOpen && root.menuHandle !== null
    color: "transparent"
    // Only the root takes keyboard focus; a submenu grabbing it would steal the
    // parent's grab and collapse the chain. Registering that with ShellFocus is
    // what gets the bar to advertise keyboard interactivity while the chain is up.
    grabFocus: root.shouldOpen && !root.isSubmenu
    onGrabFocusChanged: ShellFocus.hold(root, root.grabFocus)
    Component.onDestruction: ShellFocus.hold(root, false)

    // A submenu always opens off the side of its parent row. The root menu opens
    // off the tray icon, so in a vertical bar it goes sideways for the same reason
    // a Popout does — see Config.barPopupEdge.
    readonly property bool sideways: root.isSubmenu || Config.barVertical
    readonly property int rootEdge: root.isSubmenu ? Edges.Right : Config.barPopupEdge

    anchor.item: root.anchorItem
    anchor.edges: root.isSubmenu ? (Edges.Right | Edges.Top) : root.rootEdge
    anchor.gravity: root.isSubmenu ? (Edges.Right | Edges.Bottom) : root.rootEdge
    anchor.margins.top: root.sideways ? 0 : Theme.sp2
    anchor.margins.left: (!root.isSubmenu && root.rootEdge === Edges.Right) ? Theme.sp2 : 0
    anchor.margins.right: (!root.isSubmenu && root.rootEdge === Edges.Left) ? Theme.sp2 : 0
    anchor.adjustment: root.sideways ? (PopupAdjustment.SlideY | PopupAdjustment.FlipX) : (PopupAdjustment.SlideX | PopupAdjustment.FlipY)

    implicitWidth: root.menuWidth
    implicitHeight: panel.implicitHeight

    onShouldOpenChanged: {
        if (!root.shouldOpen)
            root.closeSubmenu();
    }

    QsMenuOpener {
        id: opener
        menu: root.shouldOpen ? root.menuHandle : null
    }

    HyprlandFocusGrab {
        active: root.shouldOpen && !root.isSubmenu
        windows: root.windowChain
        onCleared: root.rootMenu.dismissRequested()
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.shouldOpen && !root.isSubmenu
        onActivated: root.rootMenu.dismissRequested()
    }

    // Hovering a plain entry shouldn't yank an open submenu away instantly — the
    // pointer has to cross those entries to reach the submenu in the first place.
    Timer {
        id: submenuCloser
        interval: 220
        onTriggered: root.closeSubmenu()
    }

    // Off-screen width measurement.
    //
    // The menu can't size itself from the rows it displays: a positioner derives
    // its implicit width from its children's *widths*, and those rows are stretched
    // to the menu width, which would close the loop. These labels are unconstrained,
    // so the column's implicit width really is the widest label. It sits outside
    // the panel (so it can't affect the panel's content height) and is drawn at
    // zero opacity rather than visible:false, because a positioner ignores children
    // that aren't effectively visible.
    Item {
        id: measure

        readonly property int naturalWidth: Theme.sp3 * 2 + labels.implicitWidth + (root.hasLeading ? root.leadingSize + Theme.sp3 : 0) + (root.hasSubmenus ? Theme.sp4 + Theme.sp3 : 0)

        opacity: 0
        enabled: false
        z: -1

        Column {
            id: labels

            Repeater {
                model: root.entries

                delegate: Text {
                    required property QsMenuEntry modelData

                    visible: !modelData.isSeparator
                    text: root.labelText(modelData.text)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMd
                }
            }
        }
    }

    GlassPanel {
        id: panel
        width: root.menuWidth
        padding: root.menuPadding
        radius: Theme.rPill

        opacity: root.shouldOpen ? 1 : 0
        scale: root.shouldOpen ? 1 : 0.96
        transformOrigin: root.isSubmenu ? Item.TopLeft : Item.Top

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

                // A menu that hasn't answered AboutToShow yet, or that genuinely
                // has nothing in it, still needs to look like a menu rather than
                // an empty sliver.
                Text {
                    width: parent.width
                    visible: root.entries.length === 0
                    height: visible ? root.rowHeight : 0
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: "No actions"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMd
                    color: Theme.muted
                }

                Repeater {
                    model: root.entries

                    delegate: Item {
                        id: entryRow

                        required property QsMenuEntry modelData

                        readonly property bool isSeparator: entryRow.modelData.isSeparator
                        readonly property bool hasChildren: entryRow.modelData.hasChildren
                        readonly property bool actionable: !entryRow.isSeparator && entryRow.modelData.enabled
                        readonly property bool submenuOpen: root.openSubmenuEntry === entryRow.modelData
                        // Checkboxes and radios reuse the icon slot; DBusMenu never
                        // sends both for the same entry.
                        readonly property string glyph: {
                            if (entryRow.modelData.buttonType === QsMenuButtonType.CheckBox)
                                return entryRow.modelData.checkState === Qt.Unchecked ? "" : Icons.check;
                            if (entryRow.modelData.buttonType === QsMenuButtonType.RadioButton)
                                return entryRow.modelData.checkState === Qt.Unchecked ? "" : Icons.wsActive;
                            return "";
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
                            color: (entryRow.actionable && (rowMouse.containsMouse || entryRow.submenuOpen)) ? Theme.alpha(Theme.hover, 0.7) : "transparent"

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

                            Text {
                                anchors.centerIn: parent
                                visible: entryRow.glyph !== ""
                                text: entryRow.glyph
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsMd
                                color: entryRow.actionable ? Theme.accentLight : Theme.muted
                            }

                            IconImage {
                                anchors.fill: parent
                                visible: entryRow.glyph === "" && entryRow.modelData.icon !== ""
                                source: entryRow.modelData.icon
                                asynchronous: true
                                opacity: entryRow.actionable ? 1 : 0.4
                            }
                        }

                        Text {
                            visible: !entryRow.isSeparator
                            anchors.left: root.hasLeading ? leading.right : parent.left
                            anchors.leftMargin: Theme.sp3
                            anchors.right: parent.right
                            anchors.rightMargin: root.hasSubmenus ? Theme.sp4 + Theme.sp3 : Theme.sp3
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.labelText(entryRow.modelData.text)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsMd
                            color: entryRow.actionable ? Theme.text : Theme.muted
                            elide: Text.ElideRight
                        }

                        Text {
                            visible: !entryRow.isSeparator && entryRow.hasChildren
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.sp3
                            anchors.verticalCenter: parent.verticalCenter
                            text: Icons.chevronRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsMd
                            color: entryRow.actionable ? Theme.accentLight : Theme.muted
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            enabled: !entryRow.isSeparator
                            hoverEnabled: true
                            cursorShape: entryRow.actionable ? Qt.PointingHandCursor : Qt.ArrowCursor

                            onEntered: {
                                if (entryRow.actionable && entryRow.hasChildren)
                                    root.openSubmenu(entryRow.modelData, entryRow);
                                else if (root.openSubmenuEntry)
                                    submenuCloser.restart();
                            }

                            onClicked: {
                                if (!entryRow.actionable)
                                    return;
                                if (entryRow.hasChildren) {
                                    root.openSubmenu(entryRow.modelData, entryRow);
                                    return;
                                }
                                entryRow.modelData.triggered();
                                root.rootMenu.dismissRequested();
                            }
                        }
                    }
                }
            }
        }
    }

    // Bindings rather than assignments in onLoaded: the loader stays active while
    // the pointer moves between sibling submenu entries, so the handle and anchor
    // have to keep following `openSubmenuEntry` after the item already exists.
    Loader {
        id: submenuLoader
        active: root.shouldOpen && root.openSubmenuEntry !== null
        source: "TrayMenu.qml"

        onLoaded: {
            item.isSubmenu = true;
            item.rootMenu = root.rootMenu;
            item.shouldOpen = true;
        }
    }

    Binding {
        target: submenuLoader.item
        property: "menuHandle"
        value: root.openSubmenuEntry
        when: submenuLoader.item !== null
    }

    Binding {
        target: submenuLoader.item
        property: "anchorItem"
        value: root.openSubmenuAnchor
        when: submenuLoader.item !== null
    }
}
