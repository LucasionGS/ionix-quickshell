// The Ionix logo button. Opens the start menu; middle-click runs the external
// launcher, right-click gives the power menu.

import QtQuick
import QtQuick.Effects
import Quickshell
import qs.config
import qs.components
import qs.popouts
import qs.services

Item {
    id: root

    property var bar: null

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    IconButton {
        id: button
        anchors.fill: parent
        vertical: Config.barVertical
        icon: Config.launcher.icon
        fontFamily: Theme.fontLogo
        fontSize: Theme.fsTitle
        colour: Theme.accentLight
        hoverColour: Theme.textBright
        horizontalPadding: Theme.sp5
        tooltip: "Start  ·  middle-click for the launcher  ·  right-click for power"

        // start.enabled false hands the button back to launcher.command, which is
        // what it ran before the menu existed.
        onClicked: {
            if (Config.start.enabled)
                Popouts.toggle("start", root.bar?.screen);
            else
                Quickshell.execDetached(Config.launcher.command);
        }
        onMiddleClicked: Quickshell.execDetached(Config.launcher.middleCommand)
        onRightClicked: Popouts.toggle("power", root.bar?.screen)
    }

    // QML has no text-shadow, so the glow is a blurred copy of the glyph drawn
    // underneath at low opacity.
    Text {
        id: glowSource
        anchors.centerIn: parent
        text: Config.launcher.icon
        font.family: Theme.fontLogo
        font.pixelSize: Theme.fsTitle
        color: Theme.accentLight
        visible: false
    }

    MultiEffect {
        source: glowSource
        anchors.fill: glowSource
        blurEnabled: true
        blur: 1.0
        blurMax: 24
        opacity: button.hovered ? 0.55 : 0
        z: -1

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durNormal
            }
        }
    }

    StartPopout {
        anchorItem: root
        shouldOpen: Popouts.isOpen("start", root.bar?.screen)
    }

    // Hosted here rather than on BatteryIndicator because the launcher is always
    // present — the battery module hides itself on desktops, which would take the
    // power menu with it.
    PowerPopout {
        anchorItem: root
        shouldOpen: Popouts.isOpen("power", root.bar?.screen)
    }
}
