pragma Singleton

// Who and where — the start menu's footer identity.
//
// Nothing here polls unless someone sets `tracking`, because the only consumer is
// a panel that is closed most of the time and /proc/uptime cannot be watched: it
// has no inode changes to notify on, so it has to be re-read.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string user: {
        const name = Quickshell.env("USER");
        return (name && name !== "") ? name : (Quickshell.env("LOGNAME") ?? "");
    }

    property string host: ""
    property real uptimeSeconds: 0

    // Set by whatever is on screen; keeps the uptime read off the clock while the
    // menu is closed.
    property bool tracking: false

    readonly property string uptime: {
        const total = Math.floor(root.uptimeSeconds);
        if (total <= 0)
            return "";
        const days = Math.floor(total / 86400);
        const hours = Math.floor(total % 86400 / 3600);
        const minutes = Math.floor(total % 3600 / 60);
        if (days > 0)
            return `${days}d ${hours}h`;
        if (hours > 0)
            return `${hours}h ${minutes}m`;
        return `${minutes}m`;
    }

    // ~/.face is the freedesktop convention and what AccountsService copies to.
    // Probed rather than handed straight to an Image, because Image logs a warning
    // for a source it cannot open and most users have no avatar at all.
    readonly property string avatarPath: `${Quickshell.env("HOME")}/.face`
    property bool hasAvatar: false
    readonly property string avatar: root.hasAvatar ? `file://${root.avatarPath}` : ""

    onTrackingChanged: if (root.tracking)
        uptimeFile.reload()

    FileView {
        path: "/etc/hostname"
        blockLoading: true
        printErrors: false
        onLoaded: root.host = this.text().trim()
    }

    // Existence probe only — the bytes are never read back out of here, the Image
    // loads the file itself.
    FileView {
        path: root.avatarPath
        printErrors: false
        onLoaded: root.hasAvatar = true
        onLoadFailed: root.hasAvatar = false
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        printErrors: false
        // First field is seconds since boot; the second is idle time.
        onLoaded: root.uptimeSeconds = parseFloat(this.text().split(" ")[0]) || 0
    }

    Timer {
        running: root.tracking
        interval: 30000
        repeat: true
        onTriggered: uptimeFile.reload()
    }
}
