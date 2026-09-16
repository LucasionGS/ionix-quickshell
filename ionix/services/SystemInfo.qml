pragma Singleton

// Who and where — the start menu's footer identity.
//
// Nothing here polls unless someone sets `tracking`, because the only consumer is
// a panel that is closed most of the time and /proc/uptime cannot be watched: it
// has no inode changes to notify on, so it has to be re-read.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property string user: {
        const name = Quickshell.env("USER");
        return (name && name !== "") ? name : (Quickshell.env("LOGNAME") ?? "");
    }

    // The GECOS full name (`chfn -f`), or "" when it is unset or just repeats the
    // login. Asked of getent rather than read from /etc/passwd so a directory
    // account (LDAP, systemd-homed) gets its name too.
    property string realName: ""

    // What the start menu titles itself with: a name set in config wins, then the
    // account's full name, then the login.
    readonly property string displayName: {
        const configured = (Config.start.displayName ?? "").trim();
        if (configured !== "")
            return configured;
        return root.realName !== "" ? root.realName : root.user;
    }
    readonly property bool showsLogin: root.displayName !== root.user

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

    // First existing file wins: an explicit start.avatar, then the shell's own
    // $XDG_CONFIG_HOME/quickshell/avatar.png, then ~/.face — the freedesktop
    // convention and what AccountsService copies to. Probed rather than handed
    // straight to an Image, because Image logs a warning for a source it cannot
    // open and most users have no avatar at all.
    //
    // The probe is a `test -r` loop and not a FileView: a FileView that has
    // loaded a file does not report a failure when that file is later deleted,
    // so a removed picture would linger until restart.
    readonly property var avatarCandidates: {
        const home = Quickshell.env("HOME");
        const xdg = Quickshell.env("XDG_CONFIG_HOME");
        const configBase = (xdg && xdg !== "") ? xdg : home + "/.config";
        const configured = (Config.start.avatar ?? "").trim().replace(/^~(?=\/|$)/, home);
        return [configured, `${configBase}/quickshell/avatar.png`, `${home}/.face`].filter(p => p !== "");
    }
    property string avatarPath: ""
    readonly property string avatar: root.avatarPath !== "" ? `file://${root.avatarPath}` : ""

    // Re-probed every time the menu opens, so dropping a picture in place shows up
    // on the next open without restarting the shell.
    function probeAvatar() {
        avatarProbe.running = false;
        avatarProbe.running = true;
    }

    onAvatarCandidatesChanged: root.probeAvatar()

    onTrackingChanged: if (root.tracking) {
        uptimeFile.reload();
        root.probeAvatar();
    }

    Process {
        running: root.user !== ""
        command: ["getent", "passwd", root.user]
        stdout: StdioCollector {
            // name:pw:uid:gid:GECOS:home:shell, and GECOS is itself
            // "Full Name,room,work phone,home phone".
            onStreamFinished: {
                const gecos = (this.text.trim().split(":")[4] ?? "").split(",")[0].trim();
                root.realName = gecos !== root.user ? gecos : "";
            }
        }
    }

    FileView {
        path: "/etc/hostname"
        blockLoading: true
        printErrors: false
        onLoaded: root.host = this.text().trim()
    }

    // Prints the first readable candidate, or nothing. The Image loads the file
    // itself; nothing here reads the bytes.
    Process {
        id: avatarProbe
        running: true
        command: ["sh", "-c", 'for f in "$@"; do [ -f "$f" ] && [ -r "$f" ] && { printf %s "$f"; exit 0; }; done', "sh", ...root.avatarCandidates]
        stdout: StdioCollector {
            onStreamFinished: root.avatarPath = this.text
        }
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
