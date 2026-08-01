// The start menu.
//
// Windows-shaped — search, pinned grid, identity and power in a footer — with the
// three additions that make it worth having over a plain launcher:
//
//   · it knows what is already running, so Enter on an open app raises its window
//     instead of starting a second copy;
//   · the search covers shell state (Do Not Disturb, Wi-Fi, session actions), not
//     just executables;
//   · it drives ionixtheme, so the desktop's whole look is two keystrokes away.
//
// Sizing is the fragile part. GlassPanel measures itself from childrenRect and
// Popout binds implicitHeight to that, so anything in here that derived its height
// from the panel would close the loop. The scrolling body is therefore sized from
// the *screen*, and everything else is either fixed or content-driven downward.

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

Popout {
    id: root

    panelWidth: Config.start.width
    padding: Theme.sp5

    // ── State ───────────────────────────────────────────────────────────────

    property string query: ""
    // home | all — which face the body shows when nothing is typed. A non-empty
    // query always wins, so `mode` rather than `view` is what the body switches on.
    property string view: "home"
    property string category: ""
    property int selectedIndex: 0
    property string recommendMode: Config.start.recommend
    property bool powerOpen: false
    property bool themesOpen: false
    property string armed: ""
    property bool menuOpen: false

    readonly property bool searching: root.query.trim() !== ""
    readonly property string mode: root.searching ? "results" : root.view
    readonly property int contentWidth: root.panelWidth - root.padding * 2

    // ── Data ────────────────────────────────────────────────────────────────

    readonly property var results: root.searching ? StartSearch.results(root.query) : []

    // Results grouped under section headers. Sorting is global, so the section
    // holding the best match leads and the rest keep their canonical order —
    // otherwise typing a window title would bury it under an Applications header.
    readonly property var resultRows: {
        const order = ["app", "window", "action", "theme"];
        if (root.results.length > 0) {
            const lead = root.results[0].kind;
            order.splice(order.indexOf(lead), 1);
            order.unshift(lead);
        }

        const rows = [];
        let index = 0;
        for (const kind of order) {
            const inKind = root.results.filter(r => r.kind === kind);
            if (inKind.length === 0)
                continue;
            rows.push({
                header: StartSearch.sectionLabel(kind)
            });
            for (const result of inKind) {
                rows.push({
                    result: result,
                    index: index++
                });
            }
        }
        return rows;
    }

    // Selection order has to match what is on screen, not the score order the
    // sections were built from.
    readonly property var orderedResults: root.resultRows.filter(r => r.result !== undefined).map(r => r.result)

    readonly property var pinnedEntries: StartState.pins.map(id => Apps.byId(id)).filter(entry => !!entry)

    readonly property var recommendedEntries: {
        const count = Config.start.recommendCount;
        const ids = root.recommendMode === "recent" ? StartState.recent(count) : StartState.frequent(count);
        return ids.map(id => Apps.byId(id)).filter(entry => !!entry);
    }

    readonly property var filteredApps: root.category === "" ? Apps.list : Apps.list.filter(entry => Apps.inCategory(entry, root.category))

    // Open windows collapsed to one row per application, so five terminals are one
    // entry with a count rather than five near-identical rows.
    readonly property var runningGroups: {
        if (!Config.start.showRunning)
            return [];

        const groups = [];
        const seen = ({});
        const toplevels = Windows.toplevels;

        for (let i = 0; i < toplevels.length; i++) {
            const toplevel = toplevels[i];
            const appId = Windows.appId(toplevel);
            if (appId === "")
                continue;

            if (seen[appId] !== undefined) {
                groups[seen[appId]].count++;
                continue;
            }

            const entry = Windows.entryFor(toplevel);
            const iconName = Windows.iconFor(toplevel);
            seen[appId] = groups.length;
            groups.push({
                appId: appId,
                entry: entry,
                toplevel: toplevel,
                title: entry?.name ?? appId,
                icon: iconName === "" ? "" : Quickshell.iconPath(iconName, true),
                count: 1
            });
        }
        return groups;
    }

    // What the arrow keys walk. Home is mouse-driven: with no query there is no
    // ranking, so a linear cursor over a grid would be arbitrary.
    readonly property var navItems: {
        if (root.searching)
            return root.orderedResults;
        if (root.view === "all")
            return root.filteredApps;
        return [];
    }

    // ── Geometry ────────────────────────────────────────────────────────────

    // Everything outside the body — search, chips, dividers, footer, padding.
    readonly property int chromeHeight: 190

    readonly property int maxBodyHeight: Math.max(240, Math.round((root.screen?.height ?? 1080) * Config.start.maxHeightFraction) - root.chromeHeight)
    readonly property int bodyHeight: Math.max(80, Math.min(bodyLoader.height, root.maxBodyHeight))

    readonly property int tileWidth: Math.floor((root.contentWidth - Theme.sp2 * (Config.start.columns - 1)) / Config.start.columns)

    // ── Behaviour ───────────────────────────────────────────────────────────

    onShouldOpenChanged: {
        SystemInfo.tracking = root.shouldOpen;
        if (!root.shouldOpen) {
            root.menuOpen = false;
            return;
        }
        root.query = "";
        root.view = "home";
        root.category = "";
        root.selectedIndex = 0;
        root.recommendMode = Config.start.recommend;
        root.powerOpen = false;
        root.themesOpen = false;
        root.armed = "";
        root.menuOpen = false;
        searchInput.text = "";
        // Deferred: grabFocus is bound to shouldOpen, so the surface has not taken
        // keyboard focus yet at the moment this signal fires.
        Qt.callLater(() => searchInput.forceActiveFocus());
    }

    // The menu opens over a delegate in the body; switching views destroys it.
    onModeChanged: root.menuOpen = false
    onCategoryChanged: root.menuOpen = false

    onQueryChanged: root.selectedIndex = 0
    onViewChanged: root.selectedIndex = 0

    function move(delta) {
        const count = root.navItems.length;
        if (count === 0)
            return;
        root.selectedIndex = (root.selectedIndex + delta + count) % count;
    }

    function activateSelected() {
        const item = root.navItems[root.selectedIndex];
        if (!item)
            return;
        if (root.searching)
            root.run(item.activate);
        else
            root.launch(item);
    }

    // Close first: launching an application can take long enough that a menu still
    // on screen reads as a click that missed.
    function run(action) {
        Popouts.close();
        if (typeof action === "function")
            action();
    }

    function launch(entry) {
        root.run(() => Apps.launch(entry));
    }

    function focusWindow(toplevel) {
        root.run(() => Windows.activate(toplevel));
    }

    // `anchor` is the row or tile that was right-clicked; the menu opens from its
    // bottom-left and clamps itself into the panel from there.
    function openMenu(entry, anchor) {
        if (!entry)
            return;
        const at = anchor.mapToItem(tileMenu, 0, anchor.height);
        tileMenu.originX = at.x;
        tileMenu.originY = at.y;
        // Assigned, not bound: the actions are static, and a bound model would
        // rebuild every row whenever anything unrelated changed.
        tileMenu.model = root.menuFor(entry);
        tileMenu.headerText = entry.name;
        root.menuOpen = true;
    }

    // Move a pinned tile and refresh the open menu, so the next click sees where
    // the tile actually is now rather than where it was when the menu opened.
    function nudgePin(entry, delta) {
        StartState.movePin(entry.id, delta);
        tileMenu.model = root.menuFor(entry);
    }

    function menuFor(entry) {
        const pinned = StartState.isPinned(entry.id);
        const items = [
            {
                text: "Open",
                glyph: Icons.chevronRight,
                trigger: () => root.launch(entry)
            },
            {
                text: pinned ? "Unpin from Start" : "Pin to Start",
                glyph: pinned ? Icons.pinOff : Icons.pin,
                trigger: () => StartState.togglePin(entry.id)
            }
        ];

        // keepOpen, because arranging a grid is a repeated action and a menu that
        // vanished after each nudge would make it unusable.
        //
        // The model is a frozen snapshot, so `enabled` here is only true of the
        // moment the menu opened. Each nudge therefore rebuilds it — otherwise a
        // tile moved off position 0 would keep showing "Move left" greyed out, and
        // the click that should have worked would do nothing.
        if (pinned) {
            items.push({
                text: "Move left",
                glyph: Icons.chevronLeft,
                enabled: StartState.pins.indexOf(entry.id) > 0,
                keepOpen: true,
                trigger: () => root.nudgePin(entry, -1)
            }, {
                text: "Move right",
                glyph: Icons.chevronRight,
                enabled: StartState.pins.indexOf(entry.id) < StartState.pins.length - 1,
                keepOpen: true,
                trigger: () => root.nudgePin(entry, 1)
            });
        }

        const actions = Apps.actionItems(entry);
        if (actions.length > 0) {
            items.push({
                separator: true
            });
            for (const action of actions) {
                items.push({
                    text: action.text,
                    icon: action.icon,
                    trigger: () => root.run(action.trigger)
                });
            }
        }
        return items;
    }

    // Keep the keyboard cursor on screen without scrolling for mouse hover.
    function ensureVisible(item) {
        if (!item || !flick.interactive || !flick.contentItem)
            return;
        const top = item.mapToItem(flick.contentItem, 0, 0).y;
        const bottom = top + item.height;
        if (top < flick.contentY)
            flick.contentY = top;
        else if (bottom > flick.contentY + flick.height)
            flick.contentY = bottom - flick.height;
    }

    // ── Layout ──────────────────────────────────────────────────────────────

    Column {
        id: content
        width: root.contentWidth
        spacing: Theme.sp4

        // ── Search ──────────────────────────────────────────────────────────
        Rectangle {
            width: parent.width
            height: 42
            radius: Theme.rPill
            color: Theme.alpha(Theme.bgDeep, 0.6)
            border.width: 1
            border.color: searchInput.activeFocus ? Theme.accentBright : Theme.border

            Behavior on border.color {
                ColorAnimation {
                    duration: Theme.durNormal
                }
            }

            Text {
                id: searchGlyph
                anchors.left: parent.left
                anchors.leftMargin: Theme.sp4
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.search
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsIcon
                color: searchInput.activeFocus ? Theme.accentBright : Theme.muted
            }

            TextInput {
                id: searchInput
                anchors.left: searchGlyph.right
                anchors.leftMargin: Theme.sp3
                anchors.right: clearButton.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                verticalAlignment: TextInput.AlignVCenter
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsBase
                color: Theme.textBright
                selectionColor: Theme.alpha(Theme.accentBright, 0.4)
                selectByMouse: true
                clip: true

                onTextChanged: root.query = text
                onAccepted: root.activateSelected()

                Keys.onDownPressed: root.move(1)
                Keys.onUpPressed: root.move(-1)
                // Tab moves the cursor too, so the list stays reachable without
                // leaving the home row.
                Keys.onTabPressed: root.move(1)
                Keys.onBacktabPressed: root.move(-1)

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: searchInput.text === ""
                    text: "Search apps, windows, settings and themes"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsBase
                    color: Theme.muted
                }
            }

            IconButton {
                id: clearButton
                anchors.right: parent.right
                anchors.rightMargin: Theme.sp2
                anchors.verticalCenter: parent.verticalCenter
                visible: root.searching
                icon: Icons.close
                fontSize: Theme.fsMd
                colour: Theme.muted
                horizontalPadding: Theme.sp3
                onClicked: {
                    searchInput.text = "";
                    searchInput.forceActiveFocus();
                }
            }
        }

        // ── Category chips ──────────────────────────────────────────────────
        //
        // Outside the body so the filter stays put while the list under it scrolls,
        // and wrapped rather than scrolled sideways: how many categories exist
        // depends on what is installed, and a horizontal Flickable hides the
        // overflow behind a drag — the wheel does nothing on one, and there is no
        // edge affordance to say more is there.
        Item {
            width: parent.width
            height: root.mode === "all" ? chips.implicitHeight : 0
            visible: height > 0
            clip: true

            Behavior on height {
                NumberAnimation {
                    duration: Theme.durNormal
                    easing.type: Theme.easeStandard
                }
            }

            Flow {
                id: chips
                width: parent.width
                spacing: Theme.sp2

                Repeater {
                    model: [""].concat(Apps.categories)

                    delegate: Rectangle {
                        id: chip
                        required property string modelData
                        readonly property bool current: root.category === chip.modelData

                        width: chipLabel.implicitWidth + Theme.sp5
                        height: 26
                        radius: Theme.rRound
                        color: chip.current ? Theme.alpha(Theme.accentBright, 0.2) : (chipMouse.containsMouse ? Theme.alpha(Theme.hover, 0.5) : Theme.alpha(Theme.bgCard, 0.3))
                        border.width: 1
                        border.color: chip.current ? Theme.alpha(Theme.accentBright, 0.45) : "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.durNormal
                            }
                        }

                        Text {
                            id: chipLabel
                            anchors.centerIn: parent
                            text: chip.modelData === "" ? "All" : Apps.label(chip.modelData)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsXs
                            color: chip.current ? Theme.textBright : Theme.muted
                        }

                        MouseArea {
                            id: chipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.category = chip.modelData
                        }
                    }
                }
            }
        }

        // ── Body ────────────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: root.bodyHeight

            Behavior on height {
                NumberAnimation {
                    duration: Theme.durNormal
                    easing.type: Theme.easeStandard
                }
            }

            Flickable {
                id: flick
                anchors.fill: parent
                contentHeight: bodyLoader.height
                contentWidth: width
                interactive: contentHeight > height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Loader {
                    id: bodyLoader
                    width: flick.width
                    height: item ? item.implicitHeight : 0
                    // Recreated on every switch, which resets the scroll position —
                    // landing halfway down a list you just opened would be worse.
                    sourceComponent: root.mode === "results" ? resultsView : (root.mode === "all" ? allAppsView : homeView)
                }
            }

            // Scroll position indicator; there is no styled scrollbar in the shell
            // and a bare one would not match anything else here.
            Rectangle {
                anchors.right: parent.right
                width: 3
                height: Math.max(24, flick.height * (flick.height / Math.max(1, flick.contentHeight)))
                y: (flick.height - height) * (flick.contentY / Math.max(1, flick.contentHeight - flick.height))
                radius: 1.5
                visible: flick.interactive
                color: Theme.alpha(Theme.accentBright, 0.35)
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.divider
        }

        // ── Power strip ─────────────────────────────────────────────────────
        //
        // Inline rather than the existing PowerPopout: Popouts holds one panel at a
        // time, so opening that one would close this one.
        Item {
            width: parent.width
            height: root.powerOpen ? 58 : 0
            visible: height > 0
            clip: true

            Behavior on height {
                NumberAnimation {
                    duration: Theme.durNormal
                    easing.type: Theme.easeStandard
                }
            }

            Row {
                width: parent.width
                height: 52
                spacing: Theme.sp2

                Repeater {
                    model: [
                        {
                            id: "lock",
                            label: "Lock",
                            icon: Icons.lock,
                            colour: Theme.accentBright,
                            confirm: false,
                            command: Config.power.lock
                        },
                        {
                            id: "logout",
                            label: "Log out",
                            icon: Icons.logout,
                            colour: Theme.orange,
                            confirm: true,
                            command: Config.power.logout
                        },
                        {
                            id: "suspend",
                            label: "Suspend",
                            icon: Icons.suspend,
                            colour: Theme.accentBright,
                            confirm: false,
                            command: Config.power.suspend
                        },
                        {
                            id: "hibernate",
                            label: "Hibernate",
                            icon: Icons.hibernate,
                            colour: Theme.accentBright,
                            confirm: false,
                            command: Config.power.hibernate
                        },
                        {
                            id: "reboot",
                            label: "Restart",
                            icon: Icons.reboot,
                            colour: Theme.red,
                            confirm: true,
                            command: Config.power.reboot
                        },
                        {
                            id: "shutdown",
                            label: "Shut down",
                            icon: Icons.shutdown,
                            colour: Theme.red,
                            confirm: true,
                            command: Config.power.shutdown
                        }
                    ]

                    delegate: Rectangle {
                        id: tile
                        required property var modelData
                        readonly property bool isArmed: root.armed === tile.modelData.id

                        width: (root.contentWidth - Theme.sp2 * 5) / 6
                        height: 52
                        radius: Theme.rPill
                        color: tile.isArmed ? Theme.alpha(tile.modelData.colour, 0.3) : (powerMouse.containsMouse ? Theme.alpha(tile.modelData.colour, 0.15) : Theme.alpha(Theme.bgCard, 0.3))
                        border.width: 1
                        border.color: tile.isArmed ? tile.modelData.colour : "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.durNormal
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 1

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: tile.modelData.icon
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsIcon
                                color: powerMouse.containsMouse || tile.isArmed ? tile.modelData.colour : Theme.text
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: tile.width - Theme.sp2
                                horizontalAlignment: Text.AlignHCenter
                                text: tile.isArmed ? "Confirm" : tile.modelData.label
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsXs
                                font.weight: tile.isArmed ? Font.Bold : Font.Normal
                                color: tile.isArmed ? tile.modelData.colour : Theme.muted
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: powerMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            // Same two-click rule as PowerPopout: a menu one stray
                            // click away from ending the session is a bad menu.
                            onClicked: {
                                if (tile.modelData.confirm && !tile.isArmed) {
                                    root.armed = tile.modelData.id;
                                    disarm.restart();
                                    return;
                                }
                                disarm.stop();
                                root.armed = "";
                                root.run(() => Quickshell.execDetached(tile.modelData.command));
                            }
                        }
                    }
                }
            }
        }

        // ── Theme strip ─────────────────────────────────────────────────────
        //
        // Wrapped for the same reason as the chips above: the number of installed
        // themes is not ours to predict, and six of them already overflow the panel.
        Item {
            width: parent.width
            height: root.themesOpen && Themes.available ? themeGrid.implicitHeight + Theme.sp2 : 0
            visible: height > 0
            clip: true

            Behavior on height {
                NumberAnimation {
                    duration: Theme.durNormal
                    easing.type: Theme.easeStandard
                }
            }

            Grid {
                id: themeGrid
                width: parent.width
                columns: 4
                spacing: Theme.sp2

                Repeater {
                    model: Themes.list

                    delegate: Rectangle {
                        id: themeCard
                        required property string modelData
                        readonly property bool current: Themes.current === themeCard.modelData
                        readonly property var colours: Themes.swatch(themeCard.modelData)

                        width: (root.contentWidth - Theme.sp2 * (themeGrid.columns - 1)) / themeGrid.columns
                        height: 54
                        radius: Theme.rPill
                        color: themeCard.current ? Theme.alpha(Theme.accentBright, 0.18) : (themeMouse.containsMouse ? Theme.alpha(Theme.hover, 0.5) : Theme.alpha(Theme.bgCard, 0.3))
                        border.width: 1
                        border.color: themeCard.current ? Theme.alpha(Theme.accentBright, 0.45) : "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.durNormal
                            }
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.sp4
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.sp2

                            Text {
                                // Leaves the top-right corner clear for the tick.
                                width: themeCard.width - Theme.sp4 - Theme.sp6
                                text: themeCard.modelData
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsSm
                                font.weight: themeCard.current ? Font.DemiBold : Font.Normal
                                color: themeCard.current ? Theme.textBright : Theme.text
                                elide: Text.ElideRight
                            }

                            // Read out of each theme's own theme.json, so the preview
                            // is the theme rather than a guess at it. A theme that
                            // overrides no colours (the shipped one) falls through to
                            // the live palette, which is exactly what it would apply.
                            Row {
                                spacing: 3

                                Repeater {
                                    model: [themeCard.colours?.bg || Theme.bgWindow, themeCard.colours?.accent || Theme.accent, themeCard.colours?.accentBright || Theme.accentBright]

                                    delegate: Rectangle {
                                        required property var modelData

                                        width: 12
                                        height: 12
                                        radius: 6
                                        color: modelData
                                        border.width: 1
                                        border.color: Theme.alpha(Theme.border, 0.6)
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.sp3
                            anchors.top: parent.top
                            anchors.topMargin: Theme.sp3
                            visible: themeCard.current
                            text: Icons.check
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsSm
                            color: Theme.accentBright
                        }

                        MouseArea {
                            id: themeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            // Left open: ionixtheme reloads the shell's theme over IPC,
                            // and watching the menu restyle under you is the point of
                            // a live picker.
                            onClicked: Themes.apply(themeCard.modelData)
                        }
                    }
                }
            }
        }

        // ── Footer ──────────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: 36

            Item {
                id: avatarSlot
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 28
                height: 28

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.rRound
                    color: Theme.alpha(Theme.accent, 0.25)
                    border.width: 1
                    border.color: Theme.alpha(Theme.accentBright, 0.35)

                    Text {
                        anchors.centerIn: parent
                        visible: avatarImage.status !== Image.Ready
                        text: Icons.account
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsIcon
                        color: Theme.accentLight
                    }
                }

                // Empty source when there is no ~/.face, so Image never logs a failed
                // load; the glyph above stays visible in that case.
                ClippingRectangle {
                    anchors.fill: parent
                    radius: Theme.rRound
                    color: "transparent"
                    visible: avatarImage.status === Image.Ready

                    Image {
                        id: avatarImage
                        anchors.fill: parent
                        source: SystemInfo.avatar
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }
            }

            Column {
                anchors.left: avatarSlot.right
                anchors.leftMargin: Theme.sp3
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Text {
                    text: SystemInfo.user
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMd
                    font.weight: Font.DemiBold
                    color: Theme.textBright
                }

                Text {
                    visible: text !== ""
                    text: {
                        const parts = [];
                        if (SystemInfo.host !== "")
                            parts.push(SystemInfo.host);
                        if (SystemInfo.uptime !== "")
                            parts.push(`up ${SystemInfo.uptime}`);
                        return parts.join("  ·  ");
                    }
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsXs
                    color: Theme.muted
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.sp1

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: root.view === "all" ? Icons.chevronLeft : Icons.grid
                    fontSize: Theme.fsIcon
                    active: root.view === "all"
                    colour: Theme.text
                    tooltip: root.view === "all" ? "Back" : "All applications"
                    onClicked: {
                        searchInput.text = "";
                        root.view = root.view === "all" ? "home" : "all";
                        searchInput.forceActiveFocus();
                    }
                }

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Themes.available
                    icon: Icons.palette
                    fontSize: Theme.fsIcon
                    active: root.themesOpen
                    colour: Theme.text
                    tooltip: "Desktop theme"
                    onClicked: {
                        root.themesOpen = !root.themesOpen;
                        if (root.themesOpen)
                            root.powerOpen = false;
                    }
                }

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Icons.shutdown
                    fontSize: Theme.fsIcon
                    active: root.powerOpen
                    colour: root.powerOpen ? Theme.red : Theme.text
                    hoverColour: Theme.red
                    tooltip: "Power"
                    onClicked: {
                        root.powerOpen = !root.powerOpen;
                        root.armed = "";
                        if (root.powerOpen)
                            root.themesOpen = false;
                    }
                }
            }
        }
    }

    // Declared after `content` so it paints above it, and sized to exactly cover it
    // so GlassPanel's childrenRect measurement is unaffected.
    InlineMenu {
        id: tileMenu

        width: content.width
        height: content.height
        open: root.menuOpen

        onDismissed: root.menuOpen = false
    }

    Timer {
        id: disarm
        interval: 3000
        onTriggered: root.armed = ""
    }

    // ── Views ───────────────────────────────────────────────────────────────

    Component {
        id: homeView

        Column {
            width: bodyLoader.width
            spacing: Theme.sp4

            SectionHeader {
                width: parent.width
                text: root.pinnedEntries.length === 0 ? "Pinned — right-click any app to add one" : "Pinned"
                glyph: Icons.pin

                IconButton {
                    icon: Icons.grid
                    label: "All apps"
                    fontSize: Theme.fsSm
                    colour: Theme.muted
                    horizontalPadding: Theme.sp2
                    onClicked: root.view = "all"
                }
            }

            Grid {
                width: parent.width
                columns: Config.start.columns
                spacing: Theme.sp2
                visible: root.pinnedEntries.length > 0

                Repeater {
                    model: root.pinnedEntries

                    delegate: AppTile {
                        id: pinTile
                        required property var modelData

                        width: root.tileWidth
                        iconSize: Config.start.iconSize
                        iconSource: Apps.iconSource(pinTile.modelData)
                        label: pinTile.modelData.name
                        running: root.runningGroups.some(g => g.entry?.id === pinTile.modelData.id)

                        onClicked: root.launch(pinTile.modelData)
                        onRightClicked: root.openMenu(pinTile.modelData, pinTile)
                    }
                }
            }

            SectionHeader {
                width: parent.width
                visible: root.runningGroups.length > 0
                text: "Running"
                glyph: Icons.window
            }

            Column {
                width: parent.width
                spacing: 1
                visible: root.runningGroups.length > 0

                Repeater {
                    model: root.runningGroups

                    delegate: ListRow {
                        id: runRow
                        required property var modelData

                        width: parent.width
                        iconSource: runRow.modelData.icon
                        icon: Icons.window
                        title: runRow.modelData.title
                        subtitle: runRow.modelData.count === 1 ? "1 window" : `${runRow.modelData.count} windows`

                        // Focus rather than launch — this row exists precisely so a
                        // second copy is never the accidental outcome.
                        onClicked: root.focusWindow(runRow.modelData.toplevel)
                        onRightClicked: root.openMenu(runRow.modelData.entry, runRow)

                        Text {
                            text: Icons.chevronRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsSm
                            color: Theme.muted
                        }
                    }
                }
            }

            SectionHeader {
                width: parent.width
                visible: root.recommendedEntries.length > 0
                text: root.recommendMode === "recent" ? "Recent" : "Frequent"
                glyph: root.recommendMode === "recent" ? Icons.history : Icons.frequent

                IconButton {
                    icon: root.recommendMode === "recent" ? Icons.frequent : Icons.history
                    label: root.recommendMode === "recent" ? "Frequent" : "Recent"
                    fontSize: Theme.fsSm
                    colour: Theme.muted
                    horizontalPadding: Theme.sp2
                    onClicked: root.recommendMode = root.recommendMode === "recent" ? "frequent" : "recent"
                }
            }

            Grid {
                width: parent.width
                columns: Config.start.columns
                spacing: Theme.sp2
                visible: root.recommendedEntries.length > 0

                Repeater {
                    model: root.recommendedEntries

                    delegate: AppTile {
                        id: recentTile
                        required property var modelData

                        width: root.tileWidth
                        iconSize: Config.start.iconSize
                        iconSource: Apps.iconSource(recentTile.modelData)
                        label: recentTile.modelData.name
                        running: root.runningGroups.some(g => g.entry?.id === recentTile.modelData.id)

                        onClicked: root.launch(recentTile.modelData)
                        onRightClicked: root.openMenu(recentTile.modelData, recentTile)
                    }
                }
            }

            // Only reachable on a fresh profile with no pins and nothing launched.
            Text {
                width: parent.width
                visible: root.pinnedEntries.length === 0 && root.runningGroups.length === 0 && root.recommendedEntries.length === 0
                horizontalAlignment: Text.AlignHCenter
                topPadding: Theme.sp7
                text: "Start typing to search, or open All apps to pin something here."
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsSm
                color: Theme.muted
                wrapMode: Text.Wrap
            }
        }
    }

    Component {
        id: allAppsView

        Column {
            width: bodyLoader.width
            spacing: 1

            Repeater {
                model: root.filteredApps

                delegate: ListRow {
                    id: appRow
                    required property var modelData
                    required property int index

                    width: parent.width
                    iconSource: Apps.iconSource(appRow.modelData)
                    icon: Icons.apps
                    title: appRow.modelData.name
                    subtitle: Apps.subtitleFor(appRow.modelData)
                    selected: root.selectedIndex === appRow.index

                    onSelectedChanged: if (selected)
                        root.ensureVisible(appRow)
                    onClicked: root.launch(appRow.modelData)
                    onRightClicked: root.openMenu(appRow.modelData, appRow)

                    Text {
                        visible: StartState.isPinned(appRow.modelData.id)
                        text: Icons.pin
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsSm
                        color: Theme.accentLight
                    }
                }
            }
        }
    }

    Component {
        id: resultsView

        Column {
            width: bodyLoader.width
            spacing: 1

            // One delegate carrying both shapes rather than a Loader per row: a
            // Loader would put the row data a `parent` hop away from the thing that
            // needs it, and these two are cheap enough to build both.
            Repeater {
                model: root.resultRows

                delegate: Item {
                    id: resultEntry
                    required property var modelData

                    readonly property bool isHeader: resultEntry.modelData.header !== undefined
                    readonly property var result: resultEntry.modelData.result ?? null

                    width: parent.width
                    height: resultEntry.isHeader ? 28 : hit.implicitHeight

                    SectionHeader {
                        anchors.fill: parent
                        anchors.topMargin: Theme.sp3
                        visible: resultEntry.isHeader
                        text: resultEntry.modelData.header ?? ""
                    }

                    ListRow {
                        id: hit
                        anchors.fill: parent
                        visible: !resultEntry.isHeader

                        iconSource: resultEntry.result?.icon ?? ""
                        icon: resultEntry.result?.glyph ?? ""
                        title: resultEntry.result?.title ?? ""
                        subtitle: resultEntry.result?.subtitle ?? ""
                        selected: !resultEntry.isHeader && root.selectedIndex === resultEntry.modelData.index

                        onSelectedChanged: if (selected)
                            root.ensureVisible(resultEntry)
                        onClicked: root.run(resultEntry.result.activate)

                        Text {
                            visible: hit.selected
                            text: "↵"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsSm
                            color: Theme.accentBright
                        }
                    }
                }
            }

            Text {
                width: parent.width
                visible: root.results.length === 0
                horizontalAlignment: Text.AlignHCenter
                topPadding: Theme.sp7
                text: `Nothing matches “${root.query}”`
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsSm
                color: Theme.muted
                elide: Text.ElideRight
            }
        }
    }
}
