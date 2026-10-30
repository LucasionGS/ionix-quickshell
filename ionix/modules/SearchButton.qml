// A magnifier on the bar: the compact SearchBox. A click hands over to launcher.command,
// which is where searching really happens.

import QtQuick
import qs.config
import qs.services

Item {
    id: root

    property var bar: null

    implicitWidth: button.thickness
    implicitHeight: button.thickness

    BarTile {
        id: button
        anchors.fill: parent
        tooltip: "Search"
        onClicked: Launch.run(Config.launcher.command)

        Text {
            anchors.centerIn: parent
            text: Icons.search
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsIcon
            color: Theme.textBright
        }
    }
}
