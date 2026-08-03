// Philips Hue: find a bridge, pair with it, then control the lights.
//
// Two views in one panel. Until a bridge is paired this is a setup wizard;
// after that it is a Pinned / All lights list, opening on Pinned because that is
// the short list of things you actually reach for.
//
// Opening the panel is what starts polling — Hue.tracking is bound to it here,
// and nothing in the service runs while it is closed.

import QtQuick
import qs.config
import qs.components
import qs.services

Popout {
    id: root

    panelWidth: 380

    property string tab: "pinned"
    // Only one light's controls are open at a time; the panel would be taller
    // than the screen otherwise.
    property string expandedId: ""

    readonly property var visibleLights: root.tab === "pinned" ? Hue.pinnedLights : Hue.lights

    // What the master row writes to: every light on the All lights tab, only the
    // pinned set on Pinned.
    readonly property string masterTarget: root.tab === "pinned" ? "pinned" : "all"

    // The group's hue/sat/ct have no single true value — the lights disagree.
    // These hold what the user last dragged, so the handles stay where they were
    // put instead of snapping back to a number the bridge never reports.
    property real groupHue: 0
    property real groupSat: 254
    property real groupCt: 300

    onShouldOpenChanged: {
        // The only thing that turns polling on.
        Hue.tracking = root.shouldOpen;
        if (root.shouldOpen) {
            root.tab = "pinned";
            root.expandedId = "";
        } else {
            // A half-finished pairing shouldn't keep hammering the bridge from a
            // panel nobody can see.
            Hue.cancelPair();
        }
    }

    // ── Colour controls ─────────────────────────────────────────────────────

    // A labelled slider line: glyph, track, and a short readout on the right.
    // Declared before LightControls, which instantiates it — inline components
    // are resolved in declaration order.
    component SliderRow: Item {
        id: sliderRow

        property string glyph: ""
        property real value: 0
        property string readout: ""
        property alias gradient: slider.trackGradient

        signal moved(real value)

        implicitHeight: 22

        Text {
            id: sliderGlyph
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: sliderRow.glyph
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsSm
            color: Theme.muted
        }

        Text {
            id: sliderReadout
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            horizontalAlignment: Text.AlignRight
            text: sliderRow.readout
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsXs
            color: Theme.muted
        }

        StyledSlider {
            id: slider
            anchors.left: sliderGlyph.right
            anchors.leftMargin: Theme.sp3
            anchors.right: sliderReadout.left
            anchors.rightMargin: Theme.sp2
            anchors.verticalCenter: parent.verticalCenter
            trackHeight: 5
            knobSize: 13
            value: sliderRow.value
            onMoved: v => sliderRow.moved(v)
        }
    }

    // Shared by every light row and by the master row. `target` is a light id or
    // one of the literals "all" (Hue routes it to group 0) and "pinned" (Hue fans
    // it out to the pinned lights).
    component LightControls: Column {
        id: controls

        required property string target
        required property var light

        // Lets the All lights row remember where its handles were left, since the
        // bridge has no group-wide hue to read back.
        signal moved(string key, real raw)

        spacing: Theme.sp2

        SliderRow {
            width: parent.width
            visible: controls.light.dimmable
            glyph: Icons.brightness
            value: controls.light.brightness
            readout: `${Math.round(controls.light.brightness * 100)}%`
            onMoved: v => {
                Hue.setBrightness(controls.target, v);
                controls.moved("bri", v * 254);
            }
        }

        SliderRow {
            width: parent.width
            visible: controls.light.colourCapable
            glyph: Icons.palette
            value: controls.light.hue / 65535
            readout: "hue"
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0.000
                    color: "#ff0000"
                }
                GradientStop {
                    position: 0.167
                    color: "#ffff00"
                }
                GradientStop {
                    position: 0.333
                    color: "#00ff00"
                }
                GradientStop {
                    position: 0.500
                    color: "#00ffff"
                }
                GradientStop {
                    position: 0.667
                    color: "#0000ff"
                }
                GradientStop {
                    position: 0.833
                    color: "#ff00ff"
                }
                GradientStop {
                    position: 1.000
                    color: "#ff0000"
                }
            }
            onMoved: v => {
                const raw = Math.min(65535, Math.round(v * 65535));
                Hue.setLight(controls.target, {
                    on: true,
                    hue: raw
                });
                controls.moved("hue", raw);
            }
        }

        SliderRow {
            width: parent.width
            visible: controls.light.colourCapable
            glyph: Icons.wsEmpty
            value: controls.light.sat / 254
            readout: "sat"
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: "#ffffff"
                }
                GradientStop {
                    position: 1
                    color: Qt.hsva(controls.light.hue / 65535, 1, 1, 1)
                }
            }
            onMoved: v => {
                const raw = Math.round(v * 254);
                Hue.setLight(controls.target, {
                    on: true,
                    sat: raw
                });
                controls.moved("sat", raw);
            }
        }

        SliderRow {
            width: parent.width
            visible: controls.light.ctCapable
            glyph: Icons.bulb
            // Mireds run 153 (cool) to 500 (warm).
            value: (controls.light.ct - 153) / 347
            readout: "white"
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: Hue.ctColour(153)
                }
                GradientStop {
                    position: 1
                    color: Hue.ctColour(500)
                }
            }
            onMoved: v => {
                const raw = Math.round(153 + v * 347);
                Hue.setLight(controls.target, {
                    on: true,
                    ct: raw
                });
                controls.moved("ct", raw);
            }
        }

        // Quick picks. Kept even for lights with no colour support, because a
        // near-white swatch is sent as a colour temperature instead.
        Row {
            width: parent.width
            visible: controls.light.colourCapable || controls.light.ctCapable
            spacing: Theme.sp2
            topPadding: Theme.sp1

            Repeater {
                model: Config.hue.presets ?? []

                delegate: Rectangle {
                    id: preset
                    required property string modelData

                    width: 20
                    height: 20
                    radius: 10
                    color: preset.modelData
                    border.width: 1
                    border.color: Theme.alpha(Theme.border, 0.7)
                    scale: presetMouse.containsMouse ? 1.15 : 1.0

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.durFast
                            easing.type: Theme.easeOvershoot
                        }
                    }

                    MouseArea {
                        id: presetMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Hue.setColour(controls.target, preset.modelData)
                    }
                }
            }
        }
    }

    // ── Panel ───────────────────────────────────────────────────────────────

    Column {
        width: parent.width
        spacing: Theme.sp3

        // ── Header ──────────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: 26

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Hue"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsBase
                font.weight: Font.DemiBold
                color: Theme.textBright
            }

            IconButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: Hue.phase === "ready"
                horizontalPadding: Theme.sp1
                fontSize: Theme.fsMd
                icon: Icons.refresh
                colour: Hue.fetching ? Theme.accentBright : Theme.muted
                tooltip: "Refresh"
                onClicked: Hue.refresh()
            }
        }

        // Errors are shown in place rather than replacing the panel: once paired,
        // a failed poll shouldn't throw the user back to the setup screen.
        Text {
            width: parent.width
            visible: Hue.lastError !== ""
            text: Hue.lastError
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsSm
            color: Theme.red
        }

        // ── Setup ───────────────────────────────────────────────────────────
        Column {
            width: parent.width
            visible: Hue.phase !== "ready"
            spacing: Theme.sp3

            Text {
                width: parent.width
                visible: Hue.phase !== "pairing"
                wrapMode: Text.WordWrap
                text: "Find your Hue Bridge to control your lights from the bar."
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsSm
                color: Theme.muted
            }

            Item {
                width: parent.width
                height: 24
                visible: Hue.phase !== "pairing"

                IconButton {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalPadding: Theme.sp2
                    icon: Icons.search
                    label: Hue.discovering ? "Searching…" : "Find bridge"
                    fontSize: Theme.fsMd
                    colour: Theme.accentLight
                    onClicked: Hue.discover()

                    SequentialAnimation on opacity {
                        running: Hue.discovering
                        loops: Animation.Infinite
                        NumberAnimation {
                            to: 0.4
                            duration: 700
                        }
                        NumberAnimation {
                            to: 1.0
                            duration: 700
                        }
                    }
                }
            }

            // Discovered bridges
            Column {
                width: parent.width
                spacing: 2
                visible: Hue.phase === "found"

                SectionHeader {
                    width: parent.width
                    text: "Bridges"
                }

                Repeater {
                    model: Hue.bridges

                    delegate: ListRow {
                        id: bridgeRow
                        required property var modelData

                        width: parent.width
                        icon: Icons.ethernet
                        title: bridgeRow.modelData.ip
                        subtitle: bridgeRow.modelData.id !== "" ? bridgeRow.modelData.id : "Hue Bridge"
                        onClicked: Hue.pair(bridgeRow.modelData.ip, bridgeRow.modelData.id)
                    }
                }
            }

            // Pairing
            Column {
                width: parent.width
                spacing: Theme.sp2
                visible: Hue.phase === "pairing"

                ListRow {
                    width: parent.width
                    busy: true
                    title: "Press the link button on your bridge"
                    subtitle: `${Hue.pairIp}  ·  ${Hue.pairRemaining}s left`
                }

                IconButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    horizontalPadding: Theme.sp2
                    icon: Icons.close
                    label: "Cancel"
                    fontSize: Theme.fsMd
                    colour: Theme.muted
                    onClicked: Hue.cancelPair()
                }
            }

            // Manual entry. Also the whole setup path when cloudDiscovery is off.
            Column {
                width: parent.width
                spacing: Theme.sp2
                visible: Hue.phase !== "pairing"

                SectionHeader {
                    width: parent.width
                    text: "Or enter the address"
                }

                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Theme.rSm
                    color: Theme.alpha(Theme.bgDeep, 0.7)
                    border.width: 1
                    border.color: ipField.activeFocus ? Theme.accentBright : Theme.border

                    Behavior on border.color {
                        ColorAnimation {
                            duration: Theme.durNormal
                        }
                    }

                    TextInput {
                        id: ipField
                        anchors.fill: parent
                        anchors.leftMargin: Theme.sp3
                        anchors.rightMargin: 34
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsMd
                        color: Theme.textBright
                        selectionColor: Theme.alpha(Theme.accentBright, 0.4)
                        clip: true

                        onAccepted: Hue.setBridge(this.text)

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: ipField.text === ""
                            text: "192.168.1.2"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsMd
                            color: Theme.muted
                        }
                    }

                    IconButton {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalPadding: Theme.sp2
                        icon: Icons.chevronRight
                        fontSize: Theme.fsMd
                        colour: ipField.text === "" ? Theme.border : Theme.accentBright
                        onClicked: Hue.setBridge(ipField.text)
                    }
                }
            }
        }

        // ── Lights ──────────────────────────────────────────────────────────
        Column {
            width: parent.width
            visible: Hue.phase === "ready"
            spacing: Theme.sp3

            // Master row
            Column {
                width: parent.width
                spacing: Theme.sp2

                ListRow {
                    width: parent.width
                    icon: Icons.bulbGroup
                    iconColour: (root.tab === "pinned" ? Hue.pinnedAnyOn : Hue.anyOn) ? Theme.accentLight : Theme.muted
                    title: root.tab === "pinned" ? "Pinned lights" : "All lights"
                    subtitle: {
                        if (root.tab === "pinned")
                            return Hue.pinnedLights.length === 0 ? "Nothing pinned" : `${Hue.pinnedOnCount} of ${Hue.pinnedLights.length} on`;
                        return Hue.lights.length === 0 ? "No lights on this bridge" : `${Hue.onCount} of ${Hue.lights.length} on`;
                    }
                    onClicked: root.expandedId = root.expandedId === "all" ? "" : "all"

                    // No anchors: ListRow's trailing slot sizes itself from
                    // childrenRect, so a child anchoring back to it would loop.
                    Switch {
                        enabled: root.visibleLights.length > 0
                        checked: root.tab === "pinned" ? Hue.pinnedAnyOn : Hue.anyOn
                        onToggled: v => Hue.setLight(root.masterTarget, {
                                on: v
                            })
                    }
                }

                Item {
                    width: parent.width
                    height: root.expandedId === "all" ? masterControls.implicitHeight + Theme.sp2 : 0
                    clip: true
                    visible: height > 0

                    Behavior on height {
                        NumberAnimation {
                            duration: Theme.durNormal
                            easing.type: Theme.easeStandard
                        }
                    }

                    LightControls {
                        id: masterControls
                        x: Theme.sp5
                        width: parent.width - Theme.sp5 - Theme.sp3
                        target: root.masterTarget
                        light: ({
                                dimmable: true,
                                colourCapable: true,
                                ctCapable: true,
                                brightness: root.tab === "pinned" ? Hue.pinnedGroupBri : Hue.groupBri,
                                hue: root.groupHue,
                                sat: root.groupSat,
                                ct: root.groupCt
                            })
                        onMoved: (key, raw) => {
                            if (key === "hue")
                                root.groupHue = raw;
                            else if (key === "sat")
                                root.groupSat = raw;
                            else if (key === "ct")
                                root.groupCt = raw;
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.divider
            }

            // Tabs
            Rectangle {
                id: tabStrip

                width: parent.width
                height: 28
                radius: Theme.rPill
                color: Theme.alpha(Theme.bgDeep, 0.5)
                border.width: 1
                border.color: Theme.alpha(Theme.border, 0.4)

                Rectangle {
                    width: tabStrip.width / 2 - 4
                    height: tabStrip.height - 6
                    y: 3
                    x: root.tab === "pinned" ? 3 : tabStrip.width / 2 + 1
                    radius: Theme.rPill - 2
                    color: Theme.alpha(Theme.accentBright, 0.22)
                    border.width: 1
                    border.color: Theme.alpha(Theme.accentBright, 0.45)

                    Behavior on x {
                        NumberAnimation {
                            duration: Theme.durNormal
                            easing.type: Theme.easeStandard
                        }
                    }
                }

                Row {
                    anchors.fill: parent

                    Repeater {
                        model: [
                            {
                                key: "pinned",
                                label: "Pinned"
                            },
                            {
                                key: "all",
                                label: "All lights"
                            }
                        ]

                        delegate: Item {
                            id: tabItem
                            required property var modelData

                            width: tabStrip.width / 2
                            height: tabStrip.height

                            Text {
                                anchors.centerIn: parent
                                text: tabItem.modelData.label
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsSm
                                font.weight: root.tab === tabItem.modelData.key ? Font.DemiBold : Font.Normal
                                color: root.tab === tabItem.modelData.key ? Theme.textBright : Theme.muted

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.durNormal
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.tab = tabItem.modelData.key;
                                    root.expandedId = "";
                                }
                            }
                        }
                    }
                }
            }

            // Empty states
            Text {
                width: parent.width
                visible: root.visibleLights.length === 0
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: {
                    if (Hue.stale)
                        return "Loading lights…";
                    if (Hue.lights.length === 0)
                        return "This bridge has no lights";
                    return "Nothing pinned yet — pin a light from All lights";
                }
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsSm
                color: Theme.muted
                topPadding: Theme.sp3
                bottomPadding: Theme.sp3
            }

            // The list scrolls inside a capped height rather than growing the
            // panel past the bottom of the screen.
            Flickable {
                width: parent.width
                height: Math.min(listColumn.implicitHeight, root.maxContentHeight)
                contentHeight: listColumn.implicitHeight
                contentWidth: width
                interactive: contentHeight > height
                clip: interactive
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: listColumn
                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: root.visibleLights

                        delegate: Column {
                            id: lightEntry
                            required property var modelData

                            readonly property bool expanded: root.expandedId === lightEntry.modelData.id

                            width: listColumn.width
                            spacing: Theme.sp2

                            ListRow {
                                width: parent.width
                                icon: Icons.hue(lightEntry.modelData.on, true, false)
                                // The glyph carries the light's actual colour — it
                                // is the only place the colour is visible without
                                // opening the controls, so `selected` is left off
                                // to keep ListRow from overriding the tint.
                                iconColour: lightEntry.modelData.on ? lightEntry.modelData.colour : Theme.muted
                                title: lightEntry.modelData.name
                                subtitle: {
                                    if (!lightEntry.modelData.reachable)
                                        return "Unreachable";
                                    if (!lightEntry.modelData.on)
                                        return "Off";
                                    return lightEntry.modelData.dimmable ? `On  ·  ${Math.round(lightEntry.modelData.brightness * 100)}%` : "On";
                                }

                                onClicked: root.expandedId = lightEntry.expanded ? "" : lightEntry.modelData.id
                                onRightClicked: HueState.togglePin(lightEntry.modelData.id)

                                Row {
                                    spacing: Theme.sp2

                                    IconButton {
                                        anchors.verticalCenter: parent.verticalCenter
                                        horizontalPadding: Theme.sp1
                                        fontSize: Theme.fsMd
                                        icon: HueState.isPinned(lightEntry.modelData.id) ? Icons.pin : Icons.pinOff
                                        colour: HueState.isPinned(lightEntry.modelData.id) ? Theme.accentBright : Theme.border
                                        tooltip: HueState.isPinned(lightEntry.modelData.id) ? "Unpin" : "Pin"
                                        onClicked: HueState.togglePin(lightEntry.modelData.id)
                                    }

                                    Switch {
                                        anchors.verticalCenter: parent.verticalCenter
                                        enabled: lightEntry.modelData.reachable
                                        checked: lightEntry.modelData.on
                                        onToggled: v => Hue.setLight(lightEntry.modelData.id, {
                                                on: v
                                            })
                                    }
                                }
                            }

                            Item {
                                width: parent.width
                                height: lightEntry.expanded ? entryControls.implicitHeight + Theme.sp2 : 0
                                clip: true
                                visible: height > 0

                                Behavior on height {
                                    NumberAnimation {
                                        duration: Theme.durNormal
                                        easing.type: Theme.easeStandard
                                    }
                                }

                                LightControls {
                                    id: entryControls
                                    x: Theme.sp5
                                    width: parent.width - Theme.sp5 - Theme.sp3
                                    target: lightEntry.modelData.id
                                    light: lightEntry.modelData
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.divider
            visible: Hue.phase === "ready"
        }

        // ── Footer ──────────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: 22
            visible: Hue.phase === "ready"

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: HueState.bridgeIp
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsXs
                color: Theme.muted
            }

            IconButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                horizontalPadding: Theme.sp2
                icon: Icons.close
                label: "Forget bridge"
                fontSize: Theme.fsMd
                colour: Theme.muted
                onClicked: Hue.forget()
            }
        }
    }
}
