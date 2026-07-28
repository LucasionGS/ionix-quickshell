pragma Singleton

// Notification server.
//
// The shell owns org.freedesktop.Notifications outright. It used to defer to
// swaync, but swaync's D-Bus API only exposes a count and a DND flag — there is no
// way to read the notification list out of it, so a themed centre was impossible
// while it held the name. Only one process can own that name, so swaync must not
// be running; /etc/hypr/hyprland.lua no longer starts it.
//
// Two lists come out of this: `list` is everything being kept (the centre), and
// `popups` is the subset currently on screen as a toast. They are deliberately
// separate — a toast timing out must not clear the notification from the centre.

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.config

Singleton {
    id: root

    // Newest first: trackedNotifications is oldest-first, and every surface here
    // wants the most recent thing at the top.
    readonly property var list: server.trackedNotifications.values.slice().reverse()
    readonly property int count: root.list.length

    property bool dnd: false

    // Toasts are tracked by id rather than by object. A dismissed notification is
    // destroyed, and a stale QObject left in a plain array is a dangling reference
    // waiting to be dereferenced; ids can't dangle, and filtering `list` by them
    // makes a closed notification drop out of `popups` for free.
    property var popupIds: []
    readonly property var popups: root.list.filter(n => root.popupIds.indexOf(n.id) !== -1)

    // Arrival times, keyed by id — the spec gives notifications no timestamp, so
    // the only chance to record one is when it comes in.
    property var arrivals: ({})

    // Bumped on a slow timer purely so relative-time labels re-evaluate. Bindings
    // that call relativeTime() pick this up through QML's dependency capture, which
    // follows property reads inside called functions.
    property int tick: 0

    readonly property bool hasCritical: root.list.some(n => n.urgency === NotificationUrgency.Critical)

    NotificationServer {
        id: server

        // Survive a shell reload with the list intact — losing every pending
        // notification because a config file was saved is its own bug.
        keepOnReload: true
        persistenceSupported: true

        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: false
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true
        // Not advertised: nothing in the UI can compose a reply, and claiming the
        // capability invites apps to send notifications that expect one.
        inlineReplySupported: false

        onNotification: notification => {
            // Without this the notification is dropped the moment this handler
            // returns — tracking is opt-in.
            notification.tracked = true;

            const arrivals = root.arrivals;
            arrivals[notification.id] = Date.now();
            root.arrivals = arrivals;

            if (root.dnd || Config.notifications.popups === false)
                return;
            // `transient` means "toast only, don't keep it around", but it still
            // gets a popup.
            root.showPopup(notification);
        }
    }

    Timer {
        running: true
        interval: 30000
        repeat: true
        onTriggered: root.tick++
    }

    // ── Popups ──────────────────────────────────────────────────────────────

    function showPopup(n) {
        if (root.popupIds.indexOf(n.id) !== -1)
            return;
        // Newest first, and capped: a burst of twenty notifications should not
        // paper over the screen. The ones that don't fit are still in the centre.
        const max = Math.max(1, Config.notifications.maxPopups ?? 3);
        root.popupIds = [n.id].concat(root.popupIds).slice(0, max);
    }

    function hidePopup(n) {
        root.popupIds = root.popupIds.filter(id => id !== n.id);
        // A transient notification is explicitly not meant to be kept once its
        // popup is gone.
        if (n.transient)
            n.dismiss();
    }

    function hideAllPopups() {
        root.popupIds = [];
    }

    // How long a toast should stay up, in ms; 0 means "until dismissed".
    //
    // expireTimeout is seconds here, not milliseconds: -1 means "server decides"
    // and 0 means "never expire".
    function popupDuration(n) {
        if (n.urgency === NotificationUrgency.Critical)
            return 0;
        if (n.expireTimeout === 0)
            return 0;
        if (n.expireTimeout > 0)
            return n.expireTimeout * 1000;
        return Config.notifications.timeout ?? 5000;
    }

    // ── Actions ─────────────────────────────────────────────────────────────

    function dismiss(n) {
        root.popupIds = root.popupIds.filter(id => id !== n.id);
        n.dismiss();
    }

    function clearAll() {
        // Copy first: dismissing mutates the model this list is derived from.
        const all = root.list.slice();
        root.popupIds = [];
        for (const n of all)
            n.dismiss();
    }

    // `actions` comes across as a QList of QObjects, which is array-like but not
    // guaranteed to carry the Array prototype — copy it out before using find/filter.
    function actionsOf(n) {
        const out = [];
        const actions = n?.actions;
        if (!actions)
            return out;
        for (let i = 0; i < actions.length; i++)
            out.push(actions[i]);
        return out;
    }

    // The action a click on the notification body should run, if any. "default" is
    // the conventional identifier for it.
    function defaultAction(n) {
        return root.actionsOf(n).find(a => a.identifier === "default") ?? null;
    }

    // Everything that deserves its own button.
    function buttonActions(n) {
        return root.actionsOf(n).filter(a => a.identifier !== "default");
    }

    function invoke(n, action) {
        action.invoke();
        // `resident` notifications expect to stay put and update themselves — a
        // media player's next/previous buttons, for instance.
        if (!n.resident)
            root.dismiss(n);
    }

    function activate(n) {
        const action = root.defaultAction(n);
        if (action)
            root.invoke(n, action);
        else
            root.dismiss(n);
    }

    function toggleDnd() {
        root.dnd = !root.dnd;
        if (root.dnd)
            root.hideAllPopups();
    }

    function openLink(url) {
        Quickshell.execDetached(["xdg-open", url]);
    }

    // ── Presentation helpers ────────────────────────────────────────────────

    // A single image source for the notification, or "" when it has none worth
    // showing.
    //
    // `image` is not simply pixel data: when an app supplies an icon *name* rather
    // than a bitmap, Quickshell hands it back as image://icon/<name>, and its icon
    // provider paints a magenta checkerboard for names that aren't in the current
    // theme. Binding an Image straight to it therefore shows a "missing texture"
    // block for anything the theme lacks — notify-send's defaults included. So the
    // name is pulled back out and checked before it's trusted, and the card falls
    // through to a glyph when nothing resolves.
    function imageFor(n) {
        const image = n.image ?? "";
        const prefix = "image://icon/";
        if (image !== "" && image.indexOf(prefix) !== 0)
            return image;

        const named = image.indexOf(prefix) === 0 ? decodeURIComponent(image.slice(prefix.length)) : "";
        for (const candidate of [named, n.appIcon ?? "", n.desktopEntry ?? ""]) {
            if (candidate === "")
                continue;
            // An absolute path or file URL is already an image source.
            if (candidate.indexOf("/") === 0 || candidate.indexOf("file://") === 0)
                return candidate;
            const path = Quickshell.iconPath(candidate, true);
            if (path !== "")
                return path;
        }
        return "";
    }

    function urgencyColour(n) {
        if (n.urgency === NotificationUrgency.Critical)
            return Theme.red;
        if (n.urgency === NotificationUrgency.Low)
            return Theme.muted;
        return Theme.accentBright;
    }

    // Reads root.tick so callers re-evaluate on the timer above.
    function relativeTime(n) {
        root.tick;
        const at = root.arrivals[n.id];
        if (!at)
            return "";
        const secs = Math.floor((Date.now() - at) / 1000);
        if (secs < 60)
            return "now";
        const mins = Math.floor(secs / 60);
        if (mins < 60)
            return `${mins}m`;
        const hours = Math.floor(mins / 60);
        if (hours < 24)
            return `${hours}h`;
        return `${Math.floor(hours / 24)}d`;
    }
}
