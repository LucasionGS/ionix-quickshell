// The bar window.
//
// One instance per screen (see shell.qml). Sections are built from
// Config.modules.{left,center,right}, so reordering or disabling a widget is a
// JSON edit rather than a QML edit.
//
// Orientation: bar.position picks the edge, and left/right turn the bar into a
// vertical dock. Nothing here is written in terms of width or height directly —
// everything is "thickness" (the short axis, always Config.bar.height) and the
// two gap axes — so the anchor, margin and layout blocks each state the rule
// once and read the orientation off Config.barVertical.
//
// The three module lists keep their left/center/right names in the config for a
// vertical bar too, meaning start / middle / end. Renaming them would break every
// theme that spells its layout out in full for the sake of one that doesn't.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

PanelWindow {
    id: root

    required property var modelData
    screen: root.modelData

    readonly property bool vertical: Config.barVertical
    readonly property string position: Config.bar.position
    // True when the bar hugs the edge its axis starts at — top, or left.
    readonly property bool atStart: root.position !== "bottom" && root.position !== "right"
    readonly property bool atTop: !root.vertical && root.atStart

    readonly property int thickness: Config.bar.height
    // Gap between the bar and the edge it is docked to.
    readonly property int gapEdge: Config.bar.floating ? (root.vertical ? Config.bar.margin.left : Config.bar.margin.top) : 0
    // Gap at each end of the bar's long axis.
    readonly property int gapEnds: Config.bar.floating ? (root.vertical ? Config.bar.margin.top : Config.bar.margin.left) : 0

    // Namespaced so Hyprland layerrules can target the shell's surfaces.
    // All three surface types share the `ionix-` prefix, so one regex covers them.
    WlrLayershell.namespace: "ionix-bar"
    WlrLayershell.layer: WlrLayer.Top
    // OnDemand rather than None: popups of this surface inherit its focus policy,
    // and a popup that cannot take keyboard focus has its grab cleared the instant
    // it opens — which closes it again. It also lets the Wi-Fi password field type.
    //
    // Only while one is open, though. OnDemand also parks Hyprland's keyboard focus
    // on the layer as soon as the bar is clicked at all, and Hyprland will not hand
    // focus to a window that maps while a layer surface holds it — so an app started
    // from the bar or the start menu opened unfocused until the pointer moved. See
    // ShellFocus, which every focus-grabbing surface registers with.
    WlrLayershell.keyboardFocus: ShellFocus.wanted ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Stretched along its long axis and docked to one edge on the short one.
    anchors {
        top: root.vertical || root.atStart
        bottom: root.vertical || !root.atStart
        left: !root.vertical || root.position === "left"
        right: !root.vertical || root.position === "right"
    }

    margins {
        top: root.vertical ? root.gapEnds : (root.atStart ? root.gapEdge : 0)
        bottom: root.vertical ? root.gapEnds : (root.atStart ? 0 : root.gapEdge)
        left: root.vertical ? (root.position === "left" ? root.gapEdge : 0) : root.gapEnds
        right: root.vertical ? (root.position === "right" ? root.gapEdge : 0) : root.gapEnds
    }

    // Both are set unconditionally: a PanelWindow anchored to both ends of an axis
    // is stretched by the compositor and ignores the implicit size on that axis,
    // so only the docked one is ever read.
    implicitWidth: root.thickness
    implicitHeight: root.thickness
    color: "transparent"

    // Set explicitly rather than left on ExclusionMode.Auto: with margins on a
    // floating bar, Auto's accounting of the reserved strip is easy to get wrong.
    exclusiveZone: root.thickness + root.gapEdge
    exclusionMode: ExclusionMode.Normal

    // Blur clipped to the bar's rounded shape via ext-background-effect-v1. Where
    // the compositor doesn't implement it this is a no-op and the Hyprland
    // `layerrule = blur, ionix-.*` still applies (rectangular, slightly worse).
    BackgroundEffect.blurRegion: Config.bar.nativeBlur ? blurRegion : null

    Region {
        id: blurRegion
        item: background
        radius: Theme.rBar
    }

    Rectangle {
        id: background
        anchors.fill: parent
        radius: Theme.rBar
        color: Theme.barFill
        border.width: 1
        border.color: Theme.barBorder

        Behavior on color {
            ColorAnimation {
                duration: Theme.durSlow
            }
        }
    }

    // Inner top highlight — one pixel, but it's what stops the bar looking flat.
    Rectangle {
        anchors.top: background.top
        anchors.left: background.left
        anchors.right: background.right
        anchors.margins: 1
        height: 1
        color: Qt.rgba(1, 1, 1, 0.03)
    }

    // ── Sections ────────────────────────────────────────────────────────────
    // The two end sections sit against their edges; the middle one is centred on
    // the window rather than laid out between them, so the clock/media group stays
    // put no matter how far the taskbar grows.
    //
    // GridLayout rather than Row/ColumnLayout because it is the one layout type
    // that turns: with the row/column limits left at their -1 default, `flow`
    // alone decides whether the children form a single row or a single column.
    // Modules go through the Loader below with a Layout.alignment, because it is a
    // Layout's *children* that must not use anchors.
    //
    // The sections themselves are placed with x/y rather than anchored. Swapping a
    // Layout's anchors from one axis to the other — which is what a turning bar
    // needs — leaves it sized by a stale anchor pair and it collapses to a
    // negative height; positioning it by hand keeps its size purely implicit,
    // which is the one thing a Layout must be free to decide.

    GridLayout {
        id: startSection
        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        x: root.vertical ? (root.width - width) / 2 : Theme.sp3
        y: root.vertical ? Theme.sp3 : (root.height - height) / 2
        rowSpacing: Theme.sp2
        columnSpacing: Theme.sp2

        Repeater {
            model: Config.modules.left
            delegate: moduleDelegate
        }
    }

    GridLayout {
        id: centerSection
        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        x: (root.width - width) / 2
        y: (root.height - height) / 2
        rowSpacing: Theme.sp2
        columnSpacing: Theme.sp2

        Repeater {
            model: Config.modules.center
            delegate: moduleDelegate
        }
    }

    GridLayout {
        id: endSection
        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        x: root.vertical ? (root.width - width) / 2 : root.width - width - Theme.sp3
        y: root.vertical ? root.height - height - Theme.sp3 : (root.height - height) / 2
        rowSpacing: Theme.sp2
        columnSpacing: Theme.sp2

        Repeater {
            model: Config.modules.right
            delegate: moduleDelegate
        }
    }

    // Each entry in the config arrays names a QML file in this directory.
    Component {
        id: moduleDelegate

        Loader {
            id: slot
            required property string modelData
            source: Qt.resolvedUrl(modelData + ".qml")
            // Centred on the cross axis rather than stretched: a module states its
            // own short-axis size (Theme.pillHeight) and a Layout would otherwise
            // be free to grow it to fill the bar's full thickness.
            Layout.alignment: Qt.AlignCenter

            // A module that hides itself — no battery, no bluetooth adapter, Hue
            // switched off — must not keep a slot in the bar. The Loader is what
            // the layout sees and it stays visible, so its size collapses along
            // the growing axis instead. Binding the Loader's own `visible` to the
            // item's would latch off: Item.visible reports *effective* visibility,
            // so hiding the Loader would hide the item and the binding could never
            // recover.
            readonly property bool shown: slot.item?.visible ?? true
            Layout.preferredWidth: (root.vertical || slot.shown) ? slot.implicitWidth : 0
            Layout.preferredHeight: (!root.vertical || slot.shown) ? slot.implicitHeight : 0
            // Modules need the screen for per-monitor filtering and popout scoping.
            // Every module declares `property var bar`, so assign directly —
            // hasOwnProperty() is false for QML-declared properties and would
            // silently skip every module.
            onLoaded: {
                if (item)
                    item.bar = root;
            }
            onStatusChanged: {
                if (status === Loader.Error)
                    console.warn(`[ionix] unknown bar module "${modelData}" — check config.json modules list`);
            }
        }
    }
}
