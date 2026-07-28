pragma Singleton

// Audio facade over Pipewire.
//
// The PwObjectTracker below is load-bearing, not an optimisation: Quickshell only
// binds a node's `audio` property while the node is tracked, so without it every
// volume read returns null and nothing works.

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.config

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.preferredDefaultAudioSink ?? Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.preferredDefaultAudioSource ?? Pipewire.defaultAudioSource

    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream)
    readonly property var sources: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio)
    // Application streams, i.e. what's actually playing right now.
    readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream && n.isSink)

    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? true
    readonly property bool ready: !!sink?.ready

    readonly property real sourceVolume: source?.audio?.volume ?? 0
    readonly property bool sourceMuted: source?.audio?.muted ?? true

    readonly property real maxVolume: Config.audio.maxVolume
    readonly property real step: Config.audio.step

    // Which glyph family to use — headphones read differently from speakers.
    readonly property string portType: {
        const props = root.sink?.properties;
        const port = (props?.["device.form-factor"] ?? props?.["node.name"] ?? "").toLowerCase();
        if (port.includes("headset"))
            return "headset";
        if (port.includes("headphone"))
            return "headphone";
        return "default";
    }

    readonly property string description: sink?.description ?? sink?.nickname ?? sink?.name ?? "No output"

    // Track every node we read `audio` from, plus the streams shown in the mixer.
    PwObjectTracker {
        objects: [root.sink, root.source].concat(root.sinks).concat(root.sources).concat(root.streams).filter(n => !!n)
    }

    function setVolume(v) {
        if (!root.sink?.audio)
            return;
        root.sink.audio.volume = Math.max(0, Math.min(root.maxVolume, v));
    }

    function stepVolume(direction) {
        setVolume(root.volume + direction * root.step);
    }

    function toggleMute() {
        if (root.sink?.audio)
            root.sink.audio.muted = !root.sink.audio.muted;
    }

    function toggleSourceMute() {
        if (root.source?.audio)
            root.source.audio.muted = !root.source.audio.muted;
    }

    function setDefaultSink(node) {
        Pipewire.preferredDefaultAudioSink = node;
    }

    function setDefaultSource(node) {
        Pipewire.preferredDefaultAudioSource = node;
    }

    // Best-effort display name for an application stream.
    function streamName(node) {
        const p = node?.properties;
        return p?.["application.name"] ?? p?.["media.name"] ?? node?.description ?? node?.name ?? "Unknown";
    }

    function streamIcon(node) {
        const p = node?.properties;
        return p?.["application.icon-name"] ?? p?.["application.process.binary"] ?? "";
    }
}
