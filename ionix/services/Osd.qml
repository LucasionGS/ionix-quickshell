pragma Singleton

// State for the on-screen display.
//
// `armed` exists because bindings evaluate once at startup: without it the OSD
// would flash on login as soon as the volume property first resolves. Nothing can
// show the OSD until the shell has been up long enough for that to settle.

import QtQuick
import Quickshell
import qs.config

Singleton {
    id: root

    property string kind: ""        // "volume" | "brightness" | ""
    property real value: 0
    property bool muted: false
    property bool visible: false
    property bool armed: false

    Component.onCompleted: armDelay.start()

    Timer {
        id: armDelay
        interval: 1200
        onTriggered: root.armed = true
    }

    Timer {
        id: hideTimer
        interval: Config.osd.timeout
        onTriggered: root.visible = false
    }

    function show(kind, value, muted) {
        if (!root.armed || !Config.osd.enabled)
            return;
        root.kind = kind;
        root.value = value;
        root.muted = muted ?? false;
        root.visible = true;
        hideTimer.restart();
    }

    function showVolume(value, muted) {
        show("volume", value, muted);
    }

    function showBrightness(value) {
        show("brightness", value, false);
    }
}
