// One notification, drawn as a card. Shared by the centre and the toasts, so a
// notification looks the same wherever you meet it.
//
// The caller sets `width`; the height follows the content. Body text is clamped to
// `bodyLines` because a notification is a summary, not a document — an app that
// sends forty lines shouldn't be able to push everything else off the panel.

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs.config
import qs.services

Rectangle {
    id: root

    required property var notification
    property int bodyLines: 4
    // Toasts show a countdown along the bottom edge; the centre doesn't.
    property bool showLife: false
    property alias lifeWidth: life.width
    // A card in the centre sits on the popout's glass and can be nearly
    // transparent. A toast floats on the wallpaper with nothing behind it, so it
    // has to carry its own opacity or the desktop reads straight through the text.
    property bool elevated: false

    readonly property bool hovered: bodyMouse.containsMouse || closeButton.hovered
    readonly property color accent: Notifications.urgencyColour(root.notification)
    readonly property var extraActions: Notifications.buttonActions(root.notification)
    readonly property bool clickable: Notifications.defaultAction(root.notification) !== null
    readonly property string imageSource: Notifications.imageFor(root.notification)

    implicitHeight: layout.implicitHeight + Theme.sp4 * 2

    radius: Theme.rPill
    color: {
        if (root.elevated)
            return root.hovered ? Theme.alpha(Theme.hover, 0.96) : Theme.alpha(Theme.bgWindow, 0.94);
        return root.hovered ? Theme.alpha(Theme.hover, 0.55) : Theme.alpha(Theme.bgCard, 0.35);
    }
    border.width: 1
    border.color: root.notification.urgency === NotificationUrgency.Critical ? Theme.alpha(Theme.red, 0.55) : Theme.alpha(Theme.border, 0.45)
    clip: true

    Behavior on color {
        ColorAnimation {
            duration: Theme.durNormal
        }
    }

    // Urgency stripe down the leading edge — the one piece of colour that says
    // "this one matters" without shouting.
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 3
        color: root.accent
        opacity: root.notification.urgency === NotificationUrgency.Normal ? 0.5 : 1
    }

    MouseArea {
        id: bodyMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        // Left the whole card, not just the text: the default action is the
        // notification's primary affordance and deserves the whole target.
        onClicked: Notifications.activate(root.notification)
    }

    Item {
        id: layout
        anchors.fill: parent
        anchors.margins: Theme.sp4
        anchors.leftMargin: Theme.sp4 + 3
        implicitHeight: Math.max(badge.height, textColumn.implicitHeight)

        // ── App icon or supplied image ──────────────────────────────────────
        Rectangle {
            id: badge
            anchors.left: parent.left
            anchors.top: parent.top
            width: 36
            height: 36
            radius: Theme.rSm
            color: Theme.alpha(Theme.bgDeep, 0.6)

            ClippingRectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                visible: root.imageSource !== ""

                Image {
                    anchors.fill: parent
                    source: root.imageSource
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            // Nothing resolvable: plenty of notifications carry no icon at all, so
            // this needs to look deliberate rather than broken.
            Text {
                anchors.centerIn: parent
                visible: root.imageSource === ""
                text: Icons.bell
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsIcon
                color: root.accent
            }
        }

        Column {
            id: textColumn
            anchors.left: badge.right
            anchors.leftMargin: Theme.sp3
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 2

            // ── App name, age, close ────────────────────────────────────────
            Item {
                width: parent.width
                height: 16

                Text {
                    id: appName
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, parent.width - age.width - closeButton.width - Theme.sp4)
                    text: root.notification.appName !== "" ? root.notification.appName : "Notification"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsXs
                    font.weight: Font.DemiBold
                    color: root.accent
                    elide: Text.ElideRight
                }

                Text {
                    id: age
                    anchors.left: appName.right
                    anchors.leftMargin: Theme.sp2
                    anchors.verticalCenter: parent.verticalCenter
                    text: Notifications.relativeTime(root.notification)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsXs
                    color: Theme.muted
                }

                IconButton {
                    id: closeButton
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    height: 18
                    horizontalPadding: 0
                    fontSize: Theme.fsSm
                    icon: Icons.close
                    colour: Theme.muted
                    hoverColour: Theme.red
                    onClicked: Notifications.dismiss(root.notification)
                }
            }

            Text {
                width: parent.width
                visible: root.notification.summary !== ""
                text: root.notification.summary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsMd
                font.weight: Font.DemiBold
                color: Theme.textBright
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.WordWrap
            }

            Text {
                width: parent.width
                visible: root.notification.body !== ""
                text: root.notification.body
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsSm
                color: Theme.text
                // The server advertises body markup, so bodies legitimately arrive
                // with <b>/<i>/<a> in them. StyledText renders those; PlainText
                // would show the tags.
                textFormat: Text.StyledText
                onLinkActivated: link => Notifications.openLink(link)
                linkColor: Theme.accentLight
                elide: Text.ElideRight
                maximumLineCount: root.bodyLines
                wrapMode: Text.WordWrap
            }

            // ── Actions ─────────────────────────────────────────────────────
            Item {
                width: parent.width
                visible: root.extraActions.length > 0
                height: visible ? actionRow.implicitHeight + Theme.sp2 : 0

                Row {
                    id: actionRow
                    anchors.bottom: parent.bottom
                    spacing: Theme.sp2

                    Repeater {
                        model: root.extraActions

                        delegate: Rectangle {
                            id: actionButton
                            required property var modelData

                            implicitWidth: actionLabel.implicitWidth + Theme.sp4 * 2
                            implicitHeight: 24
                            radius: Theme.rSm
                            color: actionMouse.containsMouse ? Theme.alpha(Theme.accentBright, 0.22) : Theme.alpha(Theme.bgDeep, 0.5)
                            border.width: 1
                            border.color: actionMouse.containsMouse ? Theme.alpha(Theme.accentBright, 0.5) : Theme.alpha(Theme.border, 0.5)

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.durFast
                                }
                            }

                            Text {
                                id: actionLabel
                                anchors.centerIn: parent
                                text: actionButton.modelData.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsXs
                                color: actionMouse.containsMouse ? Theme.textBright : Theme.text
                            }

                            MouseArea {
                                id: actionMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Notifications.invoke(root.notification, actionButton.modelData)
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Toast countdown ─────────────────────────────────────────────────────
    // Driven by the toast window rather than a timer in here, so the same bar can
    // pause on hover without this component knowing what a hover means.
    Rectangle {
        id: life
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        visible: root.showLife
        height: 2
        color: root.accent
        opacity: 0.7
    }
}
