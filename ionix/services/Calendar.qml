pragma Singleton

// Calendar integration — the shell's side of the ionix-calendar daemon.
//
// Nothing here talks to a calendar service. The daemon (bin/ionix-calendar)
// does, for whichever provider Config.calendar.provider names, and writes what
// it learns to two files under $XDG_STATE_HOME/ionix/quickshell/calendar/:
// state.json (account, sign-in phase, errors) and events.json (the events, in
// one provider-neutral shape). This service reads those files and owns the
// daemon process, so a provider is a config value and a Python class — no QML
// knows the difference between Outlook and anything added later.
//
// The local calendar is always part of that feed while the calendar is on at
// all — "local" is the default provider, and a remote one like Outlook is
// layered on top rather than replacing it. Events carry `source` and
// `editable`; the popout's editor only opens on the latter, and the writes it
// sends (create/update/delete, JSON on the same stdin) go to whichever
// provider the daemon considers writable. `phase` below describes only the
// remote side; the local calendar has no sign-in to be in a phase of.
//
// The daemon is a child of this shell, not a systemd unit: it is spawned only
// while a provider is configured, dies with the shell through stdin EOF, and
// takes its commands (sync, login, cancel, logout) as lines on that stdin. Its
// stdout announces every file it writes ("state" / "events"), which is what
// triggers the re-read below — the FileViews are watched too, but the state
// directory may not exist until the daemon's first write, and a watch set on a
// missing path is not something to rely on.
//
// Sign-in is Microsoft's device-code flow so it can happen from a panel that
// has no web view: the daemon puts the code and URL in state.json, the popout
// shows them, the user finishes in a browser. Tokens never pass through here.
//
// Reminders are sent from this side rather than the daemon because this shell
// *is* the notification server and already keeps a clock: `notify-send -A`
// lands the toast in the shell's own centre and blocks until the Join action
// is pressed, which is the cue to open the meeting link.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    // ── Configuration ───────────────────────────────────────────────────────

    readonly property string provider: String(Config.calendar.provider ?? "local")
    readonly property bool enabled: root.provider !== "none"
    // Anything beyond the built-in local calendar — the part with a sign-in.
    readonly property bool hasRemote: root.enabled && root.provider !== "local"

    readonly property string stateDir: {
        const override = Config.calendar.stateDir;
        if (override && override !== "")
            return override;
        const xdg = Quickshell.env("XDG_STATE_HOME");
        const base = (xdg && xdg !== "") ? xdg : Quickshell.env("HOME") + "/.local/state";
        return `${base}/ionix/quickshell/calendar`;
    }

    // ── State (state.json) ──────────────────────────────────────────────────

    property var state: ({})

    // none | starting | failed | unconfigured | signedout | signin | syncing | ready.
    // "starting" is the gap between spawning the daemon and its first write —
    // the popout shows a spinner rather than a stale "signed out" from last time.
    // With provider=local this is simply "ready".
    readonly property string phase: {
        if (!root.enabled)
            return "none";
        if (!root.daemonAlive)
            return root.daemonFailed ? "failed" : "starting";
        return String(root.state.phase ?? "starting");
    }
    // The feed is usable: the daemon is up and has written its state. The
    // remote may still be signed out — that only affects `remoteReady`.
    readonly property bool ready: root.enabled && root.daemonAlive && root.state.version !== undefined && root.phase !== "starting" && root.phase !== "failed"
    readonly property bool remoteReady: root.hasRemote && (root.phase === "ready" || root.phase === "syncing")
    readonly property var account: root.state.account ?? ({})
    readonly property string accountLabel: root.account.name || root.account.email || ""
    readonly property var signin: root.state.signin ?? null
    readonly property string error: String(root.state.error ?? "")
    readonly property string lastSync: String(root.state.lastSync ?? "")
    readonly property var calendars: Array.isArray(root.state.calendars) ? root.state.calendars : []

    // The provider's display name, for buttons like "Sign in to Outlook".
    readonly property string providerLabel: {
        const known = {
            outlook: "Outlook"
        };
        return known[root.provider] ?? root.provider;
    }

    // ── Events (events.json) ────────────────────────────────────────────────

    property var feed: ({})

    // Each event gains startMs/endMs so the day filters below never re-parse
    // ISO strings inside a binding, and declined invitations drop out here once
    // rather than in every consumer.
    readonly property var events: {
        // Belt and braces with the daemon deleting the feed on sign-out: a
        // stale file must never drive reminders or the clock pill.
        if (!root.ready)
            return [];
        const list = Array.isArray(root.feed.events) ? root.feed.events : [];
        const hideDeclined = Config.calendar.hideDeclined !== false;
        const out = [];
        for (const e of list) {
            if (!e || typeof e !== "object")
                continue;
            if (hideDeclined && e.response === "declined")
                continue;
            const startMs = Date.parse(e.start);
            const endMs = Date.parse(e.end);
            if (isNaN(startMs))
                continue;
            out.push(Object.assign({}, e, {
                startMs: startMs,
                endMs: isNaN(endMs) ? startMs : Math.max(startMs, endMs)
            }));
        }
        out.sort((a, b) => (a.startMs - b.startMs) || (a.endMs - b.endMs));
        return out;
    }

    // "YYYY-M-D" → events touching that local day. Built once per feed so the
    // 42-cell month grid asks a map, not a filter, per cell. All-day events end
    // at the next midnight (exclusive), which the `endMs > dayStart` test
    // handles without special-casing them.
    readonly property var byDay: {
        const map = ({});
        for (const e of root.events) {
            const start = new Date(e.startMs);
            const cursor = new Date(start.getFullYear(), start.getMonth(), start.getDate());
            // Cap a runaway multi-week event rather than walk the whole range.
            for (let i = 0; i < 62; i++) {
                const dayStart = cursor.getTime();
                if (dayStart >= e.endMs && dayStart > e.startMs)
                    break;
                const key = root.dayKey(cursor);
                if (!map[key])
                    map[key] = [];
                map[key].push(e);
                cursor.setDate(cursor.getDate() + 1);
            }
        }
        return map;
    }

    function dayKey(d) {
        return `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;
    }

    function eventsOn(date) {
        return root.byDay[root.dayKey(date)] ?? [];
    }

    // ── Now ─────────────────────────────────────────────────────────────────

    // Minute precision: "in 12m" only changes once a minute, and this clock is
    // also what re-evaluates `upcoming` — nothing else here is on a timer.
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        enabled: root.enabled
    }

    readonly property real nowMs: clock.date.getTime()

    // Timed events that have not ended and start within the configured window,
    // ongoing ones first. Cancelled and free-time entries are not meetings.
    readonly property var upcoming: {
        const now = root.nowMs;
        const window = Math.max(0, Number(Config.calendar.upcomingWindow ?? 60)) * 60000;
        return root.events.filter(e => !e.allDay && !e.cancelled && e.showAs !== "free" && e.endMs > now && e.startMs <= now + window);
    }
    readonly property var nextEvent: root.upcoming.length > 0 ? root.upcoming[0] : null

    // "now", "in 12m", "in 1h 05m" — for the bar pill and agenda rows.
    function relative(startMs) {
        const diff = Math.round((startMs - root.nowMs) / 60000);
        if (diff <= 0)
            return "now";
        if (diff < 60)
            return `in ${diff}m`;
        const h = Math.floor(diff / 60);
        const m = diff % 60;
        return m === 0 ? `in ${h}h` : `in ${h}h ${String(m).padStart(2, "0")}m`;
    }

    function timeOf(ms) {
        return Qt.formatTime(new Date(ms), "HH:mm");
    }

    // "10:00 – 10:30", or "All day", or "Mon 10:00 – Wed 16:00" across days.
    function span(e) {
        if (e.allDay) {
            const days = Math.round((e.endMs - e.startMs) / 86400000);
            return days > 1 ? `All day · ${days} days` : "All day";
        }
        const s = new Date(e.startMs);
        const t = new Date(e.endMs);
        const sameDay = s.getFullYear() === t.getFullYear() && s.getMonth() === t.getMonth() && s.getDate() === t.getDate();
        if (sameDay)
            return `${root.timeOf(e.startMs)} – ${root.timeOf(e.endMs)}`;
        return `${Qt.formatDateTime(s, "ddd HH:mm")} – ${Qt.formatDateTime(t, "ddd HH:mm")}`;
    }

    // Minutes since the last successful sync, or -1. Read by the popout footer;
    // depends on nowMs so it ticks.
    readonly property int syncAgeMinutes: {
        const t = Date.parse(root.lastSync);
        if (isNaN(t))
            return -1;
        return Math.max(0, Math.round((root.nowMs - t) / 60000));
    }

    // ── Daemon ──────────────────────────────────────────────────────────────

    property bool daemonAlive: false
    property bool daemonFailed: false
    // False until the singleton has settled: the bindings feeding `command`
    // and `enabled` re-evaluate once more while Config's user layers land (a
    // beat after this singleton is built), so a deferred first start sees the
    // final values in the common case. When config.json overrides `bin` the
    // first start can still use the default name and be bounced by onBinChanged
    // — on a machine without the packaged ionix-calendar on PATH (a dev
    // checkout) that logs one "failed to start" warning at launch, which is
    // expected and harmless.
    property bool wantDaemon: false
    property int crashes: 0

    Component.onCompleted: {
        root.lastBin = root.bin;
        startDelay.start();
    }

    Timer {
        id: startDelay
        interval: 50
        onTriggered: root.wantDaemon = true
    }

    Process {
        id: daemon
        // command before running: properties initialise in declaration order,
        // and `running: true` on a Process with no command yet is a start
        // failure logged as "binary could not be found".
        command: [root.bin, "daemon"]
        stdinEnabled: true
        running: root.enabled && root.wantDaemon


        // Every write is announced, so the re-read never depends on inotify.
        stdout: SplitParser {
            onRead: line => {
                const what = line.trim();
                if (what === "state")
                    stateFile.reload();
                else if (what === "events")
                    eventsFile.reload();
            }
        }

        stderr: SplitParser {
            onRead: line => {
                if (line.trim() !== "")
                    console.log(`[ionix] calendar: ${line.trim()}`);
            }
        }

        // runningChanged rather than exited: a binary that cannot be started at
        // all never emits exited, only a warning and a drop back to false, and
        // that is exactly the case the "failed" phase exists to report.
        onRunningChanged: {
            if (daemon.running) {
                root.daemonAlive = true;
                root.daemonFailed = false;
                return;
            }
            root.daemonAlive = false;
            if (root.bouncing) {
                root.bouncing = false;
                root.wantDaemon = false;
                respawn.interval = 100;
                respawn.restart();
                return;
            }
            if (!root.enabled || !root.wantDaemon)
                return;
            // Still wanted, so this is a crash or a start failure. Back off
            // progressively and give up after a handful, so a missing python
            // doesn't respawn forever.
            root.crashes++;
            if (root.crashes > 5) {
                root.daemonFailed = true;
                console.warn(`[ionix] calendar: daemon exited ${root.crashes} times; giving up`);
                return;
            }
            root.wantDaemon = false;
            respawn.interval = 2000 * root.crashes;
            respawn.restart();
        }
    }

    Timer {
        id: respawn
        onTriggered: root.wantDaemon = true
    }

    onEnabledChanged: {
        root.crashes = 0;
        root.daemonFailed = false;
        if (startDelay.running)
            return;
        root.wantDaemon = true;
        if (!root.enabled) {
            root.state = ({});
            root.feed = ({});
        }
    }

    // config.json is applied live everywhere else in this shell; the daemon
    // reads the same file, so tell it when the calendar section changes. It
    // decides for itself whether anything it cares about did.
    readonly property string configFingerprint: JSON.stringify(Config.calendar)
    onConfigFingerprintChanged: root.send("reload")

    // A new binary means a new process: a Process does not restart itself when
    // its command changes. The running one is asked to quit over stdin rather
    // than killed — Config's layers settle a beat after this singleton is
    // built, so the first change lands while the daemon is still starting,
    // and killing a process mid-start makes QProcess report a start failure.
    // `bouncing` tells the exit handler to respawn at once instead of counting
    // a crash.
    readonly property string bin: String(Config.calendar.bin || "ionix-calendar")
    property string lastBin: ""
    property bool bouncing: false
    onBinChanged: {
        const changed = root.lastBin !== "" && root.lastBin !== root.bin;
        root.lastBin = root.bin;
        if (!changed || !daemon.running)
            return;
        root.bouncing = true;
        root.send("quit");
    }

    function send(cmd) {
        if (!daemon.running)
            return;
        daemon.write(cmd + "\n");
    }

    // Throttled: the popout asks on every open, and the daemon has its own
    // interval — this is for "I just accepted an invite, show it".
    property real lastSyncRequest: 0

    function sync() {
        const now = Date.now();
        if (now - root.lastSyncRequest < 30000)
            return;
        root.lastSyncRequest = now;
        root.send("sync");
    }

    function login() {
        root.send("login");
    }

    function cancelLogin() {
        root.send("cancel");
    }

    function logout() {
        root.send("logout");
    }

    // ── Writes ──────────────────────────────────────────────────────────────
    //
    // Payload fields, all optional except title on create: title, allDay,
    // date (YYYY-MM-DD), startTime/endTime (HH:mm, resolved in the local zone
    // by the daemon), days (all-day length), location, url, notes,
    // repeat ({freq: daily|weekly|monthly|yearly, interval, until} or null).
    // An update carries the series id in `id`. One line each, so the payload
    // must not contain a raw newline — JSON.stringify never emits one.

    function create(payload) {
        root.send("create " + JSON.stringify(payload));
    }

    function update(payload) {
        root.send("update " + JSON.stringify(payload));
    }

    function remove(seriesId) {
        if (seriesId && seriesId !== "")
            root.send("delete " + seriesId);
    }

    // "Open the editor for a new event on this day" — from IPC or a keybind.
    // Popouts watch the counter; the one that is open on the focused screen
    // acts on it. The popout itself is opened by the caller.
    property int editRequest: 0
    property date editRequestDate: new Date()

    function openEditor(date) {
        root.editRequestDate = date ?? new Date();
        root.editRequest++;
    }

    // Whether anything can be written at all: the daemon says so per event
    // (`editable`), but a new event needs the answer before there is one.
    readonly property bool writable: root.ready

    function openUrl(url) {
        if (url && url !== "")
            Quickshell.execDetached(["xdg-open", url]);
    }

    function join(e) {
        root.openUrl(e?.joinUrl ?? "");
    }

    // ── Files ───────────────────────────────────────────────────────────────

    function parse(view, label) {
        const raw = view.text();
        if (!raw || raw.trim() === "")
            return ({});
        try {
            const parsed = JSON.parse(raw);
            return (parsed !== null && typeof parsed === "object" && !Array.isArray(parsed)) ? parsed : ({});
        } catch (e) {
            console.warn(`[ionix] calendar ${label}: invalid JSON — ${e}`);
            return ({});
        }
    }

    FileView {
        id: stateFile
        path: `${root.stateDir}/state.json`
        watchChanges: true
        blockLoading: true
        printErrors: false
        onLoaded: root.state = root.parse(this, "state.json")
        onFileChanged: this.reload()
        onLoadFailed: root.state = ({})
    }

    FileView {
        id: eventsFile
        path: `${root.stateDir}/events.json`
        watchChanges: true
        blockLoading: true
        printErrors: false
        onLoaded: root.feed = root.parse(this, "events.json")
        onFileChanged: this.reload()
        onLoadFailed: root.feed = ({})
    }

    // ── Reminders ───────────────────────────────────────────────────────────

    // Keyed by id + start so a rescheduled occurrence reminds again. Lives only
    // as long as the shell: after a reload, anything already inside the window
    // is skipped by the `> -60s` test below rather than re-sent.
    property var reminded: ({})

    readonly property bool remindersOn: root.enabled && Config.calendar.reminders !== false && Number(Config.calendar.reminderMinutes ?? 5) > 0

    Timer {
        interval: 30000
        running: root.remindersOn
        repeat: true
        triggeredOnStart: true
        onTriggered: root.checkReminders()
    }

    function checkReminders() {
        const lead = Number(Config.calendar.reminderMinutes ?? 5) * 60000;
        const now = Date.now();
        for (const e of root.events) {
            if (e.allDay || e.cancelled || e.showAs === "free")
                continue;
            const until = e.startMs - now;
            if (until > lead || until < -60000)
                continue;
            const key = `${e.id}@${e.startMs}`;
            if (root.reminded[key])
                continue;
            const marks = root.reminded;
            marks[key] = true;
            root.reminded = marks;
            root.notify(e, Math.max(0, Math.round(until / 60000)));
        }
    }

    function notify(e, minutes) {
        const when = minutes <= 0 ? "starting now" : `in ${minutes} min`;
        const parts = [root.span(e)];
        if (e.location && e.location !== "")
            parts.push(e.location);
        // No --expire-time=0: the toast may time out, the notification stays in
        // the centre either way, and a never-expiring toast trips the countdown
        // animation in NotificationToasts (paused on a stopped animation).
        const cmd = ["notify-send", "--app-name=Calendar", "--icon=x-office-calendar", "--urgency=normal"];
        if (e.joinUrl && e.joinUrl !== "")
            cmd.push("--action=join=Join");
        else if (e.webLink && e.webLink !== "")
            cmd.push("--action=open=Open");
        cmd.push(`${e.title} ${when}`, parts.join(" · "));
        notifier.createObject(root, {
            command: cmd,
            joinUrl: e.joinUrl ?? "",
            webLink: e.webLink ?? ""
        });
    }

    // One process per toast: `--action` makes notify-send wait for the click
    // and print the chosen key, so it has to outlive this call.
    Component {
        id: notifier

        Process {
            id: toast
            property string joinUrl: ""
            property string webLink: ""
            running: true

            stdout: StdioCollector {
                onStreamFinished: {
                    const key = this.text.trim();
                    if (key === "join")
                        root.openUrl(toast.joinUrl);
                    else if (key === "open")
                        root.openUrl(toast.webLink);
                }
            }

            onExited: toast.destroy()
        }
    }
}
