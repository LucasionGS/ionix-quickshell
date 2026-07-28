// The bar window.
//
// One instance per screen (see shell.qml). Sections are built from
// Config.modules.{left,center,right}, so reordering or disabling a widget is a
// JSON edit rather than a QML edit.

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

    readonly property bool atTop: Config.bar.position !== "bottom"
    readonly property int barHeight: Config.bar.height
    readonly property int gapTop: Config.bar.floating ? Config.bar.margin.top : 0
    readonly property int gapSide: Config.bar.floating ? Config.bar.margin.left : 0

    // Namespaced so Hyprland layerrules can target the shell's surfaces.
    // All three surface types share the `ionix-` prefix, so one regex covers them.
    WlrLayershell.namespace: "ionix-bar"
    WlrLayershell.layer: WlrLayer.Top
    // OnDemand rather than None: popups of this surface inherit its focus policy,
    // and a popup that cannot take keyboard focus has its grab cleared the instant
    // it opens — which closes it again. It also lets the Wi-Fi password field type.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    anchors {
        top: root.atTop
        bottom: !root.atTop
        left: true
        right: true
    }

    margins {
        top: root.atTop ? root.gapTop : 0
        bottom: root.atTop ? 0 : root.gapTop
        left: root.gapSide
        right: root.gapSide
    }

    implicitHeight: root.barHeight
    color: "transparent"

    // Set explicitly rather than left on ExclusionMode.Auto: with margins on a
    // floating bar, Auto's accounting of the reserved strip is easy to get wrong.
    exclusiveZone: root.barHeight + root.gapTop
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
    // Left and right are anchored to their edges; centre is anchored to the
    // window's centre rather than laid out between them, so the clock/media group
    // stays put no matter how wide the taskbar grows.

    RowLayout {
        id: leftSection
        anchors.left: parent.left
        anchors.leftMargin: Theme.sp3
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.sp2

        Repeater {
            model: Config.modules.left
            delegate: moduleDelegate
        }
    }

    RowLayout {
        id: centerSection
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.sp2

        Repeater {
            model: Config.modules.center
            delegate: moduleDelegate
        }
    }

    RowLayout {
        id: rightSection
        anchors.right: parent.right
        anchors.rightMargin: Theme.sp3
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.sp2

        Repeater {
            model: Config.modules.right
            delegate: moduleDelegate
        }
    }

    // Each entry in the config arrays names a QML file in this directory.
    Component {
        id: moduleDelegate

        Loader {
            required property string modelData
            source: Qt.resolvedUrl(modelData + ".qml")
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
