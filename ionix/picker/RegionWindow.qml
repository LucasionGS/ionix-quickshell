// The share picker's area tool: one overlay per monitor while
// PickerState.selectingRegion, each taking a drag.
//
// xdph shares an area of one output, so a rectangle never crosses monitors: the
// drag is clamped to the overlay it started on, and starting on another one
// replaces it. Coordinates are this surface's, which are that output's logical
// px from its top-left corner, the form xdph wants.
//
// Outside the area is dimmed by four bands around it, kept under the blur
// rule's ignore_alpha (0.2) so the desktop being picked from stays sharp.

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config

PanelWindow {
    id: root

    required property var modelData
    screen: root.modelData

    readonly property bool isHost: root.modelData.name === PickerState.hostName
    readonly property bool active: PickerState.selectingRegion && !PickerState.finished
    readonly property bool mine: PickerState.regionScreen === root.modelData.name
    readonly property rect area: root.mine ? PickerState.regionRect : Qt.rect(0, 0, 0, 0)
    readonly property bool hasArea: root.mine && root.area.width >= 4 && root.area.height >= 4
    property bool dragging: false
    property point anchorPoint: Qt.point(0, 0)

    WlrLayershell.namespace: "ionix-share-picker-region"
    WlrLayershell.layer: WlrLayer.Overlay
    // Only one surface can hold the keyboard; the one the dialog was on.
    WlrLayershell.keyboardFocus: root.active && root.isHost ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    visible: root.active
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    onActiveChanged: if (root.active && root.isHost)
        Qt.callLater(() => keys.forceActiveFocus())

    // ── Dim ─────────────────────────────────────────────────────────────────

    readonly property color dim: Theme.alpha(Theme.bgDeep, 0.18)

    Rectangle {
        // The whole screen until there is an area on it.
        anchors.fill: parent
        visible: !root.hasArea
        color: root.dim
    }

    Rectangle {
        visible: root.hasArea
        x: 0
        y: 0
        width: parent.width
        height: root.area.y
        color: root.dim
    }
    Rectangle {
        visible: root.hasArea
        x: 0
        y: root.area.y + root.area.height
        width: parent.width
        height: parent.height - y
        color: root.dim
    }
    Rectangle {
        visible: root.hasArea
        x: 0
        y: root.area.y
        width: root.area.x
        height: root.area.height
        color: root.dim
    }
    Rectangle {
        visible: root.hasArea
        x: root.area.x + root.area.width
        y: root.area.y
        width: parent.width - x
        height: root.area.height
        color: root.dim
    }

    // The area's outline, drawn just outside it so it is not in the share.
    Rectangle {
        visible: root.hasArea
        x: root.area.x - 2
        y: root.area.y - 2
        width: root.area.width + 4
        height: root.area.height + 4
        color: "transparent"
        border.width: 2
        border.color: Theme.accentBright
        radius: 2
    }

    // ── Drag ────────────────────────────────────────────────────────────────

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.CrossCursor
        enabled: root.active

        onPressed: mouse => {
            root.dragging = true;
            root.anchorPoint = Qt.point(mouse.x, mouse.y);
            PickerState.regionScreen = root.modelData.name;
            PickerState.regionRect = Qt.rect(mouse.x, mouse.y, 0, 0);
        }
        onPositionChanged: mouse => {
            if (!root.dragging)
                return;
            const x = Math.max(0, Math.min(root.width, mouse.x));
            const y = Math.max(0, Math.min(root.height, mouse.y));
            PickerState.regionRect = Qt.rect(Math.min(x, root.anchorPoint.x), Math.min(y, root.anchorPoint.y), Math.abs(x - root.anchorPoint.x), Math.abs(y - root.anchorPoint.y));
        }
        onReleased: {
            root.dragging = false;
            // A click without a drag is not an area.
            if (!root.hasArea)
                PickerState.clearRegion();
        }
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (!root.active)
                return;
            switch (event.key) {
            case Qt.Key_Escape:
                // First Esc drops the area, the next goes back to the dialog.
                if (PickerState.regionScreen !== "")
                    PickerState.clearRegion();
                else
                    PickerState.selectingRegion = false;
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                root.shareArea();
                break;
            default:
                return;
            }
            event.accepted = true;
        }
    }

    function shareArea() {
        const name = PickerState.regionScreen;
        const r = PickerState.regionRect;
        const screen = PickerState.screens.find(s => s.name === name);
        if (screen && r.width >= 4 && r.height >= 4)
            PickerState.shareRegion(screen, r.x, r.y, r.width, r.height);
    }

    // ── Hint, before anything is drawn ──────────────────────────────────────

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.round(parent.height * 0.08)
        visible: PickerState.regionScreen === "" && root.isHost
        width: hint.implicitWidth + Theme.sp5 * 2
        height: 40
        radius: Theme.rRound
        color: Theme.tooltipFill
        border.width: 1
        border.color: Theme.panelBorder

        Text {
            id: hint
            anchors.centerIn: parent
            text: `${Icons.region}   Drag over the area to share  ·  Esc to go back`
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsBase
            color: Theme.textBright
        }
    }

    // ── Toolbar, once there is an area ──────────────────────────────────────

    Rectangle {
        id: toolbar

        // Under the area, or over it when there is no room below.
        readonly property bool below: root.area.y + root.area.height + Theme.sp4 + height <= root.height
        visible: root.hasArea && !root.dragging
        x: Math.max(Theme.sp4, Math.min(root.width - width - Theme.sp4, root.area.x + root.area.width / 2 - width / 2))
        y: below ? root.area.y + root.area.height + Theme.sp4 : Math.max(Theme.sp4, root.area.y - height - Theme.sp4)
        width: toolRow.implicitWidth + Theme.sp3 * 2
        height: toolRow.implicitHeight + Theme.sp3 * 2
        radius: Theme.rPill
        color: Theme.panelFill
        border.width: 1
        border.color: Theme.panelBorder

        Row {
            id: toolRow
            anchors.centerIn: parent
            spacing: Theme.sp3

            Text {
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: Theme.sp3
                rightPadding: Theme.sp3
                text: `${Math.round(root.area.width)} × ${Math.round(root.area.height)}  on ${root.modelData.name}`
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsMd
                color: Theme.text
            }

            PickerButton {
                text: "Redraw"
                onClicked: PickerState.clearRegion()
            }

            PickerButton {
                text: "Back"
                hint: "Esc"
                onClicked: {
                    PickerState.clearRegion();
                    PickerState.selectingRegion = false;
                }
            }

            PickerButton {
                primary: true
                glyph: Icons.screenShare
                text: "Share area"
                hint: "Enter"
                onClicked: root.shareArea()
            }
        }
    }
}
