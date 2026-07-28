// A slider with an accent-glow knob. Used for volume, seek and brightness.
//
// Built on a MouseArea rather than QtQuick.Controls Slider so the visuals aren't
// fighting a style plugin, and so drag/click/scroll behave identically everywhere.

import QtQuick
import qs.config

Item {
    id: root

    property real value: 0          // 0..1
    property real step: 0.05
    property bool enabled: true
    property color fillColour: Theme.accentBright
    property int trackHeight: 6
    property int knobSize: 15

    // Emitted continuously while dragging and on click/scroll.
    signal moved(real value)

    implicitHeight: Math.max(knobSize, trackHeight) + 4
    implicitWidth: 120

    readonly property real _clamped: Math.max(0, Math.min(1, value))
    readonly property real _usable: width - knobSize
    readonly property real _knobX: _usable * _clamped

    // Track
    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        x: root.knobSize / 2
        width: root._usable
        height: root.trackHeight
        radius: height / 2
        color: Theme.alpha(Theme.bgDeep, 0.75)
        border.width: 1
        border.color: Theme.alpha(Theme.border, 0.5)

        Rectangle {
            width: Math.max(0, Math.min(parent.width, root._knobX))
            height: parent.height
            radius: parent.radius
            color: root.enabled ? root.fillColour : Theme.border

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durNormal
                }
            }
        }
    }

    // Knob
    Rectangle {
        id: knob
        y: (root.height - height) / 2
        x: root._knobX
        width: root.knobSize
        height: root.knobSize
        radius: width / 2
        color: root.enabled ? Theme.textBright : Theme.muted
        border.width: 2
        border.color: root.enabled ? root.fillColour : Theme.border
        scale: mouse.pressed ? 1.2 : (mouse.containsMouse ? 1.1 : 1.0)

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durFast
                easing.type: Theme.easeOvershoot
            }
        }

        // Glow, brightest while dragging.
        Rectangle {
            anchors.centerIn: parent
            width: parent.width + 8
            height: parent.height + 8
            radius: width / 2
            z: -1
            color: "transparent"
            border.width: 4
            border.color: Theme.alpha(root.fillColour, mouse.containsMouse || mouse.pressed ? 0.28 : 0.12)

            Behavior on border.color {
                ColorAnimation {
                    duration: Theme.durNormal
                }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        preventStealing: true

        function apply(mx) {
            const v = Math.max(0, Math.min(1, (mx - root.knobSize / 2) / root._usable));
            root.moved(v);
        }

        onPressed: event => apply(event.x)
        onPositionChanged: event => {
            if (pressed)
                apply(event.x);
        }
        onWheel: event => {
            const delta = event.angleDelta.y > 0 ? root.step : -root.step;
            root.moved(Math.max(0, Math.min(1, root._clamped + delta)));
            event.accepted = true;
        }
    }
}
