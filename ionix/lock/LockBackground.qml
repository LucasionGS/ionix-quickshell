// One monitor's lock background: the video or picture from LockMedia, blurred
// and dimmed while the password card is up, clear and slowly drifting while the
// screensaver is.
//
// Layers, bottom up: a themed gradient (so no picture at all still looks
// intended), the picture crossfading between slides, the video over it once it
// is actually playing, then the dim wash, a vignette and an accent glow that
// sits behind wherever the caller says the card is.

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.config

Item {
    id: root

    property string screenName: ""
    property int screenIndex: 0
    property bool awake: true
    property bool leaving: false
    // Centre of the password card in this item's coordinates, for the glow.
    property point glowCentre: Qt.point(width / 2, height / 2)
    property real glowStrength: 1

    readonly property var bg: Config.lock.background ?? ({})
    readonly property bool motion: Config.lock.screensaver?.motion !== false

    readonly property string videoPath: LockMedia.videoFor(root.screenName)
    readonly property string imagePath: LockMedia.imageFor(root.screenName, root.screenIndex)
    property bool videoFailed: false
    readonly property bool videoShown: videoLoader.item?.showing === true && !root.videoFailed

    // The one number the blur and the edge zoom both follow. Animated here
    // rather than on the effect, so the zoom that hides the blur's soft edges
    // moves in step with it.
    property real blurLevel: root.awake && !root.leaving ? clamp01(root.bg.blur ?? 0.7) : 0
    Behavior on blurLevel {
        NumberAnimation {
            duration: 700
            easing.type: Easing.OutCubic
        }
    }

    readonly property real dimLevel: {
        const d = clamp01(root.bg.dim ?? 0.35);
        return root.awake ? d : d * 0.3;
    }

    function clamp01(v) {
        const n = Number(v);
        return isNaN(n) ? 0 : Math.max(0, Math.min(1, n));
    }

    function fileUrl(path) {
        return path !== "" ? "file://" + path.split("/").map(encodeURIComponent).join("/") : "";
    }

    clip: true

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Theme.bgWindow
            }
            GradientStop {
                position: 1
                color: Theme.bgDeep
            }
        }
    }

    Item {
        id: scene
        anchors.fill: parent
        // Blur samples past the edges into nothing and darkens a rim; zooming
        // in a little while blurred pushes that rim off screen.
        scale: 1 + 0.06 * root.blurLevel

        layer.enabled: root.blurLevel > 0.002
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: root.blurLevel
            blurMax: 64
            blurMultiplier: 0.5
            saturation: 0.1 * root.blurLevel
        }

        Item {
            id: drift
            anchors.fill: parent

            Image {
                id: slideA
                anchors.fill: parent
                opacity: 0
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                sourceSize: root.decodeSize
            }

            Image {
                id: slideB
                anchors.fill: parent
                opacity: 0
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                sourceSize: root.decodeSize
            }

            Loader {
                id: videoLoader
                anchors.fill: parent
                active: root.videoPath !== "" && !root.videoFailed
                source: "LockVideo.qml"
                opacity: root.videoShown ? 1 : 0
                onLoaded: item.path = Qt.binding(() => root.videoPath)
                onStatusChanged: if (status === Loader.Error)
                    root.videoFailed = true

                Behavior on opacity {
                    NumberAnimation {
                        duration: 900
                    }
                }

                Connections {
                    target: videoLoader.item
                    function onFailed() {
                        root.videoFailed = true;
                    }
                }
            }
        }

        // Ken Burns on stills, only while nobody is looking at the card:
        // paused rather than stopped when the card comes up, so it resumes
        // where it was instead of jumping back.
        SequentialAnimation {
            running: root.motion && !root.videoShown
            paused: root.awake
            loops: Animation.Infinite

            ParallelAnimation {
                NumberAnimation {
                    target: drift
                    property: "scale"
                    from: 1.0
                    to: 1.09
                    duration: 38000
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    target: drift
                    property: "x"
                    from: 0
                    to: -root.width * 0.025
                    duration: 38000
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    target: drift
                    property: "y"
                    from: 0
                    to: root.height * 0.015
                    duration: 38000
                    easing.type: Easing.InOutSine
                }
            }
            ParallelAnimation {
                NumberAnimation {
                    target: drift
                    property: "scale"
                    to: 1.0
                    duration: 38000
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    target: drift
                    property: "x"
                    to: 0
                    duration: 38000
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    target: drift
                    property: "y"
                    to: 0
                    duration: 38000
                    easing.type: Easing.InOutSine
                }
            }
        }
    }

    // ── Slides ──────────────────────────────────────────────────────────────
    //
    // Two Images taking turns: the incoming one loads at opacity 0 and only
    // fades in once decoded, so a slow file never shows a gap.

    property Image front: null
    // Decoded a little over screen size, so the drift's zoom has pixels to spare.
    readonly property size decodeSize: Qt.size(Math.ceil(root.width * 1.15), Math.ceil(root.height * 1.15))

    function showPicture(path) {
        const url = root.fileUrl(path);
        if (root.front && root.front.source.toString() === url)
            return;
        const back = root.front === slideA ? slideB : slideA;
        back.source = url;
        if (back.status === Image.Ready)
            root.reveal(back);
    }

    function reveal(img) {
        if (img === root.front)
            return;
        const old = root.front;
        root.front = img;
        fadeIn.target = img;
        fadeIn.restart();
        if (old) {
            fadeOut.target = old;
            fadeOut.restart();
        }
    }

    NumberAnimation {
        id: fadeIn
        property: "opacity"
        to: 1
        duration: 1400
        easing.type: Easing.InOutQuad
    }

    NumberAnimation {
        id: fadeOut
        property: "opacity"
        to: 0
        duration: 1400
        easing.type: Easing.InOutQuad
    }

    Connections {
        target: slideA
        function onStatusChanged() {
            if (slideA.status === Image.Ready && slideA.source.toString() === root.fileUrl(root.imagePath))
                root.reveal(slideA);
        }
    }

    Connections {
        target: slideB
        function onStatusChanged() {
            if (slideB.status === Image.Ready && slideB.source.toString() === root.fileUrl(root.imagePath))
                root.reveal(slideB);
        }
    }

    onImagePathChanged: if (width > 0)
        showPicture(imagePath)
    onWidthChanged: if (width > 0 && !root.front)
        showPicture(imagePath)

    // ── Wash ────────────────────────────────────────────────────────────────

    Rectangle {
        anchors.fill: parent
        color: Theme.bgDeep
        opacity: root.dimLevel

        Behavior on opacity {
            NumberAnimation {
                duration: 700
                easing.type: Easing.OutCubic
            }
        }
    }

    // Darker towards the bottom, where the media card and power buttons sit.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.height * 0.4
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "transparent"
            }
            GradientStop {
                position: 1
                color: Theme.alpha(Theme.bgDeep, 0.65)
            }
        }
    }

    // The accent glow behind the card. A radial gradient on a Shape rather than
    // a blurred rectangle: one pass, no offscreen layer.
    Shape {
        anchors.fill: parent
        opacity: root.glowStrength * (root.awake ? 1 : 0)
        preferredRendererType: Shape.CurveRenderer

        Behavior on opacity {
            NumberAnimation {
                duration: 700
                easing.type: Easing.OutCubic
            }
        }

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: root.glowCentre.x
                centerY: root.glowCentre.y
                centerRadius: Math.min(root.width, root.height) * 0.55
                focalX: centerX
                focalY: centerY
                GradientStop {
                    position: 0
                    color: Theme.alpha(Theme.accentBright, 0.22)
                }
                GradientStop {
                    position: 0.45
                    color: Theme.alpha(Theme.accent, 0.08)
                }
                GradientStop {
                    position: 1
                    color: "transparent"
                }
            }
            startX: 0
            startY: 0
            PathLine {
                x: root.width
                y: 0
            }
            PathLine {
                x: root.width
                y: root.height
            }
            PathLine {
                x: 0
                y: root.height
            }
            PathLine {
                x: 0
                y: 0
            }
        }
    }
}
