// The dock: pinned and running apps as icons on a floating plate, along one screen edge.
// One per screen, and off unless a theme or the user sets dock.enabled.
//
// The surface spans the whole edge and only ever keeps its size; the input mask is what
// makes everything but the plate click through. So magnifying icons never resizes or
// re-centres a layer surface, which a compositor would show as jitter. Zoom is worked
// out from where each icon *rests*, not where it currently is, or the icons moving
// under the pointer would feed back into their own size.
//
// It wears the theme's tokens. dock.leading and dock.trailing add the shell's own items
// beside the apps, so it is the same dock under any theme.

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.config
import qs.modules
import qs.services

PanelWindow {
    id: root

    required property var modelData
    screen: root.modelData

    readonly property string position: Config.dock.position
    readonly property bool vertical: root.position === "left" || root.position === "right"
    readonly property int iconSize: Config.dock.iconSize
    readonly property real magnification: Math.max(1, Config.dock.magnification)
    readonly property int edgeGap: Config.dock.margin
    readonly property int padding: Math.round(root.iconSize * 0.12)
    readonly property int plateThickness: root.iconSize + root.padding * 2
    // Room for an icon at full size and the name above it, so neither is ever clipped.
    readonly property int surfaceThickness: Math.round(root.iconSize * root.magnification) + root.padding + root.edgeGap + 44

    // Autohide: what the plate does when nothing has asked for it.
    readonly property bool autoHide: Config.dock.autoHide === true
    readonly property bool held: root.hovered || root.menuOpenCount > 0 || root.previewKey !== ""
    readonly property bool hidden: root.autoHide && !root.held

    // ── Items ───────────────────────────────────────────────────────────────
    function builtin(name) {
        if (name === "appgrid")
            return {
                key: "appgrid",
                title: "All Apps",
                logo: true,
                windows: [],
                activate: () => AppGrid.toggle()
            };
        if (name === "taskview")
            return {
                key: "taskview",
                title: "Task View",
                glyph: Icons.window,
                windows: [],
                activate: () => TaskView.toggle()
            };
        return null;
    }

    // Shell items, the apps, a divider, and each dock.trailing entry: an item of its
    // own, { title, icon, glyph, command }. Each has the same shape to draw. An icon the
    // theme does not have falls back to the glyph.
    readonly property var entries: {
        const out = [];
        for (const name of Config.dock.leading ?? []) {
            const item = root.builtin(name);
            if (item)
                out.push(item);
        }
        for (const group of AppGroups.forScreen(root.modelData))
            out.push(group);
        const trailing = Config.dock.trailing ?? [];
        if (trailing.length > 0)
            out.push({
                key: "divider",
                divider: true,
                windows: []
            });
        for (const extra of trailing)
            out.push({
                key: `extra-${extra.title}`,
                title: extra.title,
                iconSource: extra.icon ? Quickshell.iconPath(extra.icon, true) : "",
                glyph: extra.glyph,
                windows: [],
                activate: () => Launch.run(extra.command)
            });
        return out;
    }

    readonly property int dividerSpan: Theme.sp5 + 1
    readonly property int restLength: {
        let total = root.padding * 2;
        for (const entry of root.entries)
            total += entry.divider ? root.dividerSpan : root.iconSize;
        return total;
    }

    // ── Pointer ─────────────────────────────────────────────────────────────
    property bool hovered: false
    // Along the dock's long axis, in surface coordinates.
    property real pointer: -1
    property int menuOpenCount: 0
    // The slot actually under the pointer, which zoom moves away from its rest place.
    property var overSlot: null
    // Which app's thumbnails are up. Held here so moving to the next icon swaps them.
    property string previewKey: ""
    // Leaving the plate only starts the thumbnails' countdown if they did not take the
    // pointer: that can reach them before the dock has finished noticing it left.
    property bool previewHovered: false

    onPreviewKeyChanged: {
        if (root.previewKey === "")
            root.previewHovered = false;
    }

    function lingerPreview() {
        if (root.previewKey !== "" && !root.previewHovered)
            previewLinger.restart();
    }

    onOverSlotChanged: {
        const slot = root.overSlot;
        if (slot?.running) {
            previewLinger.stop();
            if (root.previewKey !== "")
                root.previewKey = slot.item.key;
            else
                previewDelay.restart();
        }
        else {
            previewDelay.stop();
            // Past the icons but still on the dock is the way to the thumbnails, however
            // slowly it is crossed. Leaving the dock from there counts when it happens.
            if (slot || !pointerArea.containsMouse)
                root.lingerPreview();
        }
    }

    Timer {
        id: previewDelay
        interval: 400
        onTriggered: {
            if (root.overSlot?.running)
                root.previewKey = root.overSlot.item.key;
        }
    }

    // Long enough to cross the gap between an icon and its thumbnails.
    Timer {
        id: previewLinger
        interval: 280
        onTriggered: {
            root.previewKey = "";
            if (!pointerArea.containsMouse)
                root.hovered = false;
        }
    }

    function restCentre(index) {
        let at = (root.longSide - root.restLength) / 2 + root.padding;
        for (let i = 0; i < index; i++)
            at += root.entries[i].divider ? root.dividerSpan : root.iconSize;
        return at + root.iconSize / 2;
    }

    readonly property int longSide: root.vertical ? root.height : root.width

    // A raised cosine three icons wide, which is what makes the swell look like one
    // smooth bump rather than a row of steps.
    function zoomAt(index) {
        if (!root.hovered || root.magnification <= 1 || root.menuOpenCount > 0)
            return 1;
        const reach = root.iconSize * 2.6;
        const distance = Math.abs(root.pointer - root.restCentre(index));
        if (distance >= reach)
            return 1;
        const wave = Math.cos(distance / reach * Math.PI / 2);
        return 1 + (root.magnification - 1) * wave * wave;
    }

    // ── Surface ─────────────────────────────────────────────────────────────
    WlrLayershell.namespace: "ionix-dock"
    WlrLayershell.layer: WlrLayer.Top
    // Same as the bar: a popup of this surface needs focus, and holding it any longer
    // would keep a window that opens from getting it.
    WlrLayershell.keyboardFocus: ShellFocus.wanted ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors {
        top: root.position !== "bottom"
        bottom: root.position !== "top"
        left: root.position !== "right"
        right: root.position !== "left"
    }

    implicitWidth: root.surfaceThickness
    implicitHeight: root.surfaceThickness
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: root.autoHide ? 0 : root.plateThickness + root.edgeGap

    mask: Region {
        item: hitArea
    }

    BackgroundEffect.blurRegion: blurRegion

    Region {
        id: blurRegion
        item: plate
        radius: plate.radius
    }

    // What takes the pointer: the plate, plus what is drawn past it once it is hovered.
    // Hidden, a strip along the screen edge is enough to bring it back.
    Item {
        id: hitArea
        readonly property int reach: root.hidden ? 3 : (root.hovered ? root.surfaceThickness : root.plateThickness + root.edgeGap)
        x: root.vertical ? (root.position === "left" ? 0 : root.width - width) : plate.x
        y: root.vertical ? plate.y : (root.position === "top" ? 0 : root.height - height)
        width: root.vertical ? hitArea.reach : plate.width
        height: root.vertical ? plate.height : hitArea.reach

        MouseArea {
            id: pointerArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

            function slotAt(event) {
                const at = mapToItem(row, event.x, event.y);
                return row.childAt(at.x, at.y);
            }

            onContainsMouseChanged: {
                if (containsMouse) {
                    leaveDelay.stop();
                    root.hovered = true;
                }
                else {
                    leaveDelay.restart();
                    root.overSlot = null;
                }
            }
            onPositionChanged: event => {
                const at = mapToItem(null, event.x, event.y);
                root.pointer = root.vertical ? at.y : at.x;
                root.overSlot = slotAt(event);
            }
            onClicked: event => {
                previewDelay.stop();
                root.previewKey = "";
                const slot = slotAt(event);
                if (slot?.click)
                    slot.click(event.button);
            }
        }
    }

    // Leaving the plate through the gap under a magnified icon is not leaving, and
    // neither is crossing to the thumbnails: the icons hold still until those go.
    Timer {
        id: leaveDelay
        interval: 120
        onTriggered: {
            if (root.previewKey !== "")
                root.lingerPreview();
            else
                root.hovered = false;
        }
    }

    // ── Plate ───────────────────────────────────────────────────────────────
    Rectangle {
        id: plate
        readonly property real slide: root.hidden ? root.plateThickness + root.edgeGap : 0

        x: root.vertical ? (root.position === "left" ? root.edgeGap - plate.slide : root.width - width - root.edgeGap + plate.slide) : (root.width - width) / 2
        y: root.vertical ? (root.height - height) / 2 : (root.position === "top" ? root.edgeGap - plate.slide : root.height - height - root.edgeGap + plate.slide)
        width: root.vertical ? root.plateThickness : row.implicitWidth + root.padding * 2
        height: root.vertical ? row.implicitHeight + root.padding * 2 : root.plateThickness
        radius: Config.dock.radius
        color: Theme.dockFill
        border.width: 1
        border.color: Theme.barBorder

        Behavior on x {
            enabled: root.vertical
            NumberAnimation {
                duration: Theme.durSlide
                easing.type: Theme.easeStandard
            }
        }
        Behavior on y {
            enabled: !root.vertical
            NumberAnimation {
                duration: Theme.durSlide
                easing.type: Theme.easeStandard
            }
        }

        // Grid rather than Row: the one positioner that can run either way.
        Grid {
            id: row
            x: root.padding
            y: root.padding
            rows: root.vertical ? Math.max(1, root.entries.length) : 1
            columns: root.vertical ? 1 : Math.max(1, root.entries.length)

            Repeater {
                model: root.entries

                delegate: Item {
                    id: slot
                    required property var modelData
                    required property int index

                    readonly property var item: slot.modelData
                    readonly property bool isDivider: slot.item.divider === true
                    readonly property bool running: (slot.item.windows?.length ?? 0) > 0
                    readonly property real zoom: slot.isDivider ? 1 : root.zoomAt(slot.index)
                    property real shownZoom: slot.zoom
                    readonly property int span: slot.isDivider ? root.dividerSpan : Math.round(root.iconSize * slot.shownZoom)
                    property bool menuOpen: false
                    property bool bouncing: false

                    Behavior on shownZoom {
                        NumberAnimation {
                            duration: root.hovered ? 70 : Theme.durSlide
                            easing.type: Easing.OutQuad
                        }
                    }

                    width: root.vertical ? root.iconSize : slot.span
                    height: root.vertical ? slot.span : root.iconSize

                    onMenuOpenChanged: root.menuOpenCount += slot.menuOpen ? 1 : -1
                    // The list rebuilds when a window comes or goes, menu open or not.
                    Component.onDestruction: {
                        if (slot.menuOpen)
                            root.menuOpenCount--;
                    }
                    // The thumbnails follow their icon as its neighbours settle.
                    onXChanged: {
                        if (preview.visible)
                            preview.anchor.updateAnchor();
                    }
                    onYChanged: {
                        if (preview.visible)
                            preview.anchor.updateAnchor();
                    }
                    onRunningChanged: {
                        if (slot.running)
                            slot.bouncing = false;
                    }

                    function click(button) {
                        if (slot.isDivider)
                            return;
                        if (button === Qt.RightButton) {
                            const items = slot.item.entry ? AppGroups.menuFor(slot.item, "Dock") : [];
                            if (items.length > 0) {
                                menu.model = items;
                                slot.menuOpen = !slot.menuOpen;
                            }
                        }
                        else if (slot.item.activate) {
                            slot.item.activate();
                        }
                        else if (button === Qt.MiddleButton) {
                            slot.bouncing = true;
                            AppGroups.launch(slot.item);
                        }
                        else {
                            slot.bouncing = !slot.running;
                            AppGroups.activate(slot.item);
                        }
                    }

                    Rectangle {
                        visible: slot.isDivider
                        anchors.centerIn: parent
                        width: root.vertical ? root.iconSize * 0.7 : 1
                        height: root.vertical ? 1 : root.iconSize * 0.7
                        color: Theme.divider
                    }

                    // The artwork, always rendered at full size and scaled down, so the
                    // zoom never asks for a new raster. Grows out of the plate's edge.
                    Item {
                        id: art
                        visible: !slot.isDivider
                        readonly property int full: Math.round(root.iconSize * root.magnification)
                        width: art.full
                        height: art.full
                        x: root.vertical ? (root.position === "left" ? 0 : parent.width - width) : (parent.width - width) / 2
                        y: root.vertical ? (parent.height - height) / 2 : (root.position === "top" ? 0 : parent.height - height)
                        scale: slot.shownZoom / root.magnification
                        transformOrigin: root.position === "left" ? Item.Left : (root.position === "right" ? Item.Right : (root.position === "top" ? Item.Top : Item.Bottom))

                        // A launch hops until its window arrives, or three times.

                        transform: Translate {
                            id: hop
                        }

                        SequentialAnimation {
                            running: slot.bouncing
                            loops: 3
                            onStopped: {
                                hop.y = 0;
                                hop.x = 0;
                                slot.bouncing = false;
                            }

                            NumberAnimation {
                                target: hop
                                property: root.vertical ? "x" : "y"
                                to: (root.position === "top" || root.position === "left" ? 1 : -1) * root.iconSize * 0.42
                                duration: 240
                                easing.type: Easing.OutQuad
                            }
                            NumberAnimation {
                                target: hop
                                property: root.vertical ? "x" : "y"
                                to: 0
                                duration: 240
                                easing.type: Easing.InQuad
                            }
                        }

                        IconImage {
                            anchors.fill: parent
                            visible: (slot.item.iconSource ?? "") !== ""
                            source: slot.item.iconSource ?? ""
                            asynchronous: true
                        }

                        // A tile for the shell's own items, and for an app with no icon.
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: art.full * 0.06
                            visible: (slot.item.iconSource ?? "") === ""
                            radius: width * 0.23
                            gradient: Gradient {
                                GradientStop {
                                    position: 0
                                    color: Theme.mix(Theme.bgCard, Theme.textBright, 0.14)
                                }
                                GradientStop {
                                    position: 1
                                    color: Theme.bgCard
                                }
                            }
                            border.width: Math.max(1, art.full * 0.012)
                            border.color: Theme.controlStroke

                            Text {
                                anchors.centerIn: parent
                                text: {
                                    if (slot.item.logo)
                                        return Config.launcher.icon;
                                    return slot.item.glyph ?? (slot.item.title ?? "?").charAt(0).toUpperCase();
                                }
                                font.family: slot.item.logo ? Theme.fontLogo : Theme.fontFamily
                                font.pixelSize: art.full * (slot.item.logo ? 0.62 : 0.5)
                                color: slot.item.logo ? Theme.accentLight : Theme.textBright
                            }
                        }
                    }

                    // An app with a window: a dot on the plate between the icon and the edge.
                    Rectangle {
                        visible: slot.running
                        readonly property int side: 4
                        width: side
                        height: side
                        radius: side / 2
                        color: Theme.textBright
                        x: root.vertical ? (root.position === "left" ? -root.padding + (root.padding - side) / 2 : parent.width + (root.padding - side) / 2) : (parent.width - side) / 2
                        y: root.vertical ? (parent.height - side) / 2 : (root.position === "top" ? -root.padding + (root.padding - side) / 2 : parent.height + (root.padding - side) / 2)
                    }

                    // The name, past the icon, while the pointer is over it.
                    Rectangle {
                        readonly property bool over: root.hovered && root.overSlot === slot && !slot.isDivider && !slot.menuOpen && root.previewKey !== slot.item.key
                        visible: over
                        width: nameText.implicitWidth + Theme.sp5
                        height: nameText.implicitHeight + Theme.sp3
                        radius: Theme.rSm
                        color: Theme.tooltipFill
                        border.width: 1
                        border.color: Theme.panelBorder
                        readonly property int lift: Math.round(root.iconSize * slot.shownZoom) - root.iconSize + Theme.sp3
                        x: root.vertical ? (root.position === "left" ? parent.width + lift : -width - lift) : (parent.width - width) / 2
                        y: root.vertical ? (parent.height - height) / 2 : (root.position === "top" ? parent.height + lift : -height - lift)

                        Text {
                            id: nameText
                            anchors.centerIn: parent
                            text: slot.item.title ?? ""
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsBase
                            color: Theme.textBright
                        }
                    }

                    TaskPreview {
                        id: preview
                        anchorItem: slot
                        edge: root.position === "left" ? Edges.Right : (root.position === "right" ? Edges.Left : (root.position === "top" ? Edges.Bottom : Edges.Top))
                        // Past the icon at full size, wherever the pointer leaves it.
                        extraGap: Math.round(root.iconSize * (root.magnification - 1)) + root.padding
                        shouldOpen: root.previewKey === slot.item.key && slot.running && !slot.menuOpen
                        windows: slot.item.windows ?? []
                        onEntered: {
                            root.previewHovered = true;
                            previewLinger.stop();
                        }
                        onExited: {
                            root.previewHovered = false;
                            root.lingerPreview();
                        }
                        onDismissed: {
                            root.previewKey = "";
                            root.hovered = false;
                        }
                    }

                    ContextMenu {
                        id: menu
                        anchorItem: slot
                        shouldOpen: slot.menuOpen
                        onDismissRequested: slot.menuOpen = false
                    }
                }
            }
        }
    }
}
