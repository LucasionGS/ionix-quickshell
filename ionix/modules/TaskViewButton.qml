// The button for Task View (osd/TaskViewOverlay): every window and workspace. Scroll
// over it to change workspace. In the default bar and every shipped theme; hidden by
// taskView.enabled, the switch on the start menu's settings page.

import QtQuick
import QtQuick.Shapes
import qs.config
import qs.services

Item {
    id: root

    property var bar: null

    visible: Config.taskView.enabled
    implicitWidth: button.thickness + (Config.barVertical ? 0 : 4)
    implicitHeight: button.thickness + (Config.barVertical ? 4 : 0)

    BarTile {
        id: button
        anchors.fill: parent
        active: TaskView.active
        tooltip: "Task View"
        onClicked: TaskView.toggle()
        onScrolled: direction => TaskView.step(-direction)

        // Two overlapping panes. The one behind is an open path, stopping where the
        // front one begins, so it needs no fill to hide behind and shows the same on a
        // glass bar as on a solid one.
        Shape {
            anchors.centerIn: parent
            width: 20
            height: 16
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: Theme.text
                strokeWidth: 1.3
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                startX: 6
                startY: 3

                PathLine {
                    x: 6
                    y: 2
                }
                PathArc {
                    x: 8
                    y: 0.6
                    radiusX: 2
                    radiusY: 2
                }
                PathLine {
                    x: 17.5
                    y: 0.6
                }
                PathArc {
                    x: 19.4
                    y: 2.5
                    radiusX: 2
                    radiusY: 2
                }
                PathLine {
                    x: 19.4
                    y: 9
                }
                PathArc {
                    x: 17.5
                    y: 10.8
                    radiusX: 2
                    radiusY: 2
                }
                PathLine {
                    x: 15.5
                    y: 10.8
                }
            }

            Rectangle {
                x: 0.6
                y: 4.6
                width: 13.4
                height: 10.8
                radius: 2
                color: "transparent"
                border.width: 1.3
                border.color: Theme.accentLight
            }
        }
    }
}
