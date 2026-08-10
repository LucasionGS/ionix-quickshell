// A one-of-N picker, sized to sit in a ListRow's trailing slot beside the
// switches so it reads as the same class of control.
//
// Used for theme options that offer a `choices` list rather than an on/off
// patch — see the "Theme options" comment in config/Config.qml.

import QtQuick
import qs.config

Row {
    id: root

    // [{ value, label, glyph }] — label is the tooltip, glyph is what's drawn.
    // A choice with no glyph falls back to its label as the segment's text.
    property var options: []
    property var value
    property bool enabled: true

    signal picked(var value)

    spacing: 2
    opacity: root.enabled ? 1 : 0.4

    Repeater {
        model: root.options

        delegate: Rectangle {
            id: seg
            required property var modelData

            readonly property bool current: seg.modelData.value === root.value
            readonly property string glyph: (seg.modelData.glyph && seg.modelData.glyph !== "") ? seg.modelData.glyph : (seg.modelData.label ?? "")
            readonly property bool hovered: segMouse.containsMouse

            width: Math.max(26, caption.implicitWidth + Theme.sp3)
            height: 24
            radius: Theme.rSm
            color: {
                if (seg.current)
                    return Theme.alpha(Theme.accentBright, 0.85);
                return seg.hovered && root.enabled ? Theme.alpha(Theme.hover, 0.6) : Theme.alpha(Theme.bgDeep, 0.8);
            }
            border.width: 1
            border.color: seg.current ? Theme.accentBright : Theme.border

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durNormal
                }
            }
            Behavior on border.color {
                ColorAnimation {
                    duration: Theme.durNormal
                }
            }

            Text {
                id: caption
                anchors.centerIn: parent
                text: seg.glyph
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsMd
                color: seg.current ? Theme.bgDeep : Theme.text

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durNormal
                    }
                }
            }

            MouseArea {
                id: segMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.enabled
                cursorShape: Qt.PointingHandCursor
                onClicked: root.picked(seg.modelData.value)
            }

            Tooltip {
                target: seg
                shown: seg.hovered && (seg.modelData.label ?? "") !== ""
                text: seg.modelData.label ?? ""
            }
        }
    }
}
