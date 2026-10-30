// A flat bar button: no fill until the pointer is over it, a subtle one while held
// or while its flyout is open. What a module draws on top of it is its own business;
// this is only the hit area and the backplate, so the modules built on it all light
// up alike. Colours and radius come from the theme, so it wears any of them.

import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property bool active: false
    property string tooltip: ""
    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed

    default property alias content: holder.data

    signal clicked
    signal rightClicked
    signal middleClicked
    signal scrolled(int direction)

    // The short axis of the bar, whichever way the bar runs; the module states the other.
    readonly property int thickness: Theme.pillHeight
    implicitWidth: root.thickness
    implicitHeight: root.thickness

    Rectangle {
        anchors.fill: parent
        radius: Theme.rSm
        color: {
            if (root.pressed)
                return Theme.subtlePressed;
            if (root.hovered || root.active)
                return Theme.subtleHover;
            return "transparent";
        }
        border.width: root.active ? 1 : 0
        border.color: Theme.controlStroke

        Behavior on color {
            ColorAnimation {
                duration: Theme.durFast
            }
        }
    }

    Item {
        id: holder
        anchors.fill: parent
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: event => {
            if (event.button === Qt.LeftButton)
                root.clicked();
            else if (event.button === Qt.RightButton)
                root.rightClicked();
            else
                root.middleClicked();
        }
        onWheel: event => {
            root.scrolled(event.angleDelta.y > 0 ? 1 : -1);
            event.accepted = true;
        }
    }

    // Hidden by a click until the pointer comes back: the flyout it opened is what
    // should have the attention now.
    property bool tipDismissed: false
    onHoveredChanged: root.tipDismissed = false
    onClicked: root.tipDismissed = true
    onRightClicked: root.tipDismissed = true

    Tooltip {
        text: root.tooltip
        target: root
        sideways: Config.barVertical
        shown: root.hovered && root.tooltip !== "" && !root.active && !root.tipDismissed
    }
}
