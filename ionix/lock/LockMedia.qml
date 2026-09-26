pragma Singleton

// What goes behind the lock on each monitor: a video, a picture, a slideshow
// from a directory, or whatever awww is showing there right now.
//
// awww is asked rather than read from a file because nothing else records the
// wallpaper per output — ionix-wallpaper keeps copies in .wallpapers_active, but
// not which monitor each belongs to. It is re-asked every `interval` seconds, so
// the wallpaper cron changing pictures under a long lock carries through.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.config

Singleton {
    id: root

    readonly property var bg: Config.lock.background ?? ({})
    readonly property int interval: Math.max(5, bg.interval ?? 60)

    // output name → picture path, from `awww query`.
    property var wallpapers: ({})
    // directory → its pictures, shuffled once when first listed.
    property var slides: ({})
    // Advances every `interval`; each screen offsets it by its own index so a
    // slideshow across several monitors doesn't show the same picture on all.
    property int tick: 0

    readonly property bool videoAllowed: bg.videoOnBattery === true || !UPower.onBattery

    // Where the Ionix default picture lives, for a first-boot lock that runs
    // before awww has put anything on screen.
    readonly property string fallbackImage: "/usr/local/share/ionix/wallpaper.png"

    function expand(path) {
        if (typeof path !== "string")
            return "";
        return path.trim().replace(/^~(?=\/|$)/, Quickshell.env("HOME"));
    }

    // A config value that may be a plain string or a { "<output>": …, "*": … } map.
    function forScreen(value, name) {
        if (typeof value === "string")
            return root.expand(value);
        if (value !== null && typeof value === "object" && !Array.isArray(value))
            return root.expand(value[name] ?? value["*"] ?? "");
        return "";
    }

    function videoFor(name) {
        return root.videoAllowed ? root.forScreen(root.bg.video, name) : "";
    }

    function isDirectory(path) {
        return root.slides[path] !== undefined;
    }

    // `index` is the screen's position, used only to stagger slideshows.
    function imageFor(name, index) {
        const configured = root.forScreen(root.bg.image, name);
        if (configured !== "") {
            const list = root.slides[configured];
            if (list === undefined)
                return configured;
            return list.length > 0 ? list[(root.tick + index) % list.length] : "";
        }
        // An output awww isn't drawing on (just plugged in, or a nested
        // session's) borrows another monitor's picture rather than going bare.
        const own = root.wallpapers[name] ?? root.wallpapers["*"];
        if (own)
            return own;
        const any = Object.keys(root.wallpapers);
        return any.length > 0 ? root.wallpapers[any[0]] : root.fallbackImage;
    }

    // Every configured path that might be a directory, so each can be listed
    // once. A plain file lists as nothing and is then used as itself.
    readonly property var candidateDirs: {
        const out = [];
        const v = root.bg.image;
        if (typeof v === "string") {
            if (v.trim() !== "")
                out.push(root.expand(v));
        } else if (v !== null && typeof v === "object") {
            for (const k in v)
                if (typeof v[k] === "string" && v[k].trim() !== "")
                    out.push(root.expand(v[k]));
        }
        return out.filter((p, i) => out.indexOf(p) === i);
    }

    onCandidateDirsChanged: lister.list()

    // ── awww ────────────────────────────────────────────────────────────────

    Process {
        id: query
        command: ["awww", "query"]
        stdout: StdioCollector {
            onStreamFinished: {
                // ": DP-1: 1080x1920, scale: 1, currently displaying: image: /path"
                const map = {};
                for (const line of this.text.split("\n")) {
                    const m = line.match(/^:?\s*([^:\s]+):.*currently displaying: image: (.+)$/);
                    if (m)
                        map[m[1]] = m[2].trim();
                }
                // At session start the lock can beat awww-daemon up. Show the
                // Ionix default meanwhile and ask again shortly.
                if (Object.keys(map).length === 0) {
                    // Keep the last real answer through a daemon restart.
                    if (Object.keys(root.wallpapers).some(k => k !== "*"))
                        return;
                    map["*"] = root.fallbackImage;
                    if (retry.attempts++ < 10)
                        retry.start();
                }
                if (JSON.stringify(map) !== JSON.stringify(root.wallpapers))
                    root.wallpapers = map;
            }
        }
    }

    Timer {
        id: retry
        property int attempts: 0
        interval: 1500
        onTriggered: query.running = true
    }

    // ── Slideshow directories ───────────────────────────────────────────────

    Process {
        id: lister
        property var pending: []

        function list() {
            pending = root.candidateDirs.slice();
            next();
        }

        function next() {
            if (pending.length === 0)
                return;
            const dir = pending.shift();
            command = ["find", "-L", dir, "-maxdepth", "1", "-type", "f", "(", "-iname", "*.png", "-o", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.webp", "-o", "-iname", "*.avif", "-o", "-iname", "*.jxl", ")"];
            current = dir;
            running = true;
        }

        property string current: ""

        stdout: StdioCollector {
            onStreamFinished: {
                const files = this.text.split("\n").filter(f => f !== "");
                // find on a picture prints the picture itself, which marks the
                // path as a file; only a directory that held pictures becomes a
                // slideshow.
                if (files.length > 0 && !(files.length === 1 && files[0] === lister.current)) {
                    for (let i = files.length - 1; i > 0; i--) {
                        const j = Math.floor(Math.random() * (i + 1));
                        [files[i], files[j]] = [files[j], files[i]];
                    }
                    const next = Object.assign({}, root.slides);
                    next[lister.current] = files;
                    root.slides = next;
                }
            }
        }

        onExited: next()
    }

    Timer {
        interval: root.interval * 1000
        running: true
        repeat: true
        onTriggered: {
            root.tick++;
            query.running = true;
        }
    }

    Component.onCompleted: {
        query.running = true;
        lister.list();
    }
}
