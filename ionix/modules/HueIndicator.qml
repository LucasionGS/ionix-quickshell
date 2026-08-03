// Philips Hue lights. Off unless Config.hue.enabled, because most machines have
// no bridge and an always-visible bulb that never lights up is just noise.

import QtQuick
import qs.config
import qs.components
import qs.popouts
import qs.services

Item {
    id: root

    property var bar: null
    readonly property bool popoutOpen: Popouts.isOpen("hue", root.bar?.screen)

    visible: Config.hue.enabled
    implicitWidth: visible ? button.implicitWidth : 0
    implicitHeight: Theme.pillHeight

    IconButton {
        id: button
        anchors.fill: parent

        active: root.popoutOpen
        icon: Icons.hue(Hue.anyOn, Hue.phase === "ready", Hue.stale)
        // Only claims a lit colour once a fetch has actually landed. Between
        // login and the first time the panel is opened the shell has never
        // spoken to the bridge, and the icon says so by staying muted.
        colour: (!Hue.stale && Hue.anyOn) ? Theme.accentLight : Theme.muted

        tooltip: {
            if (Hue.phase !== "ready")
                return "Hue — not set up";
            if (Hue.stale)
                return "Hue lights";
            if (Hue.lights.length === 0)
                return "Hue — no lights";
            return `${Hue.onCount} of ${Hue.lights.length} lights on`;
        }

        onClicked: Popouts.toggle("hue", root.bar?.screen)
        // Quick all-off without opening anything, the same shortcut
        // BluetoothIndicator gives the adapter.
        onMiddleClicked: {
            if (Hue.phase === "ready")
                Hue.setAll({
                    on: !Hue.anyOn
                });
        }
        onScrolled: delta => {
            if (Hue.phase === "ready")
                Hue.stepGroupBrightness(delta);
        }
    }

    HuePopout {
        anchorItem: root
        shouldOpen: root.popoutOpen
    }
}
