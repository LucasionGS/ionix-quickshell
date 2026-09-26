// A looped, muted video for the lock's background.
//
// Its own file, loaded through a Loader, so that a machine without QtMultimedia
// (or without a backend for it) loses only the video: the import fails here, the
// Loader reports an error, and LockBackground keeps the picture it already had.

import QtQuick
import QtMultimedia

Video {
    id: root

    property string path: ""
    // True once a frame has actually been shown — the picture underneath stays
    // until then, so a slow start never flashes black.
    readonly property bool showing: root.playbackState === MediaPlayer.PlayingState && root.position > 0

    signal failed

    source: root.path !== "" ? "file://" + root.path.split("/").map(encodeURIComponent).join("/") : ""
    autoPlay: true
    loops: MediaPlayer.Infinite
    muted: true
    fillMode: VideoOutput.PreserveAspectCrop

    onErrorOccurred: (error, errorString) => {
        console.warn(`[ionix-lock] video ${root.path}: ${errorString}`);
        root.failed();
    }
}
