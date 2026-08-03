pragma Singleton

// Philips Hue bridge client — discovery, pairing, light state and control.
//
// Speaks the CLIP **v1** API over plain HTTP. v2 is HTTPS-only behind a
// self-signed certificate that QML's XMLHttpRequest cannot be told to accept, so
// v2 would mean shelling out to `curl -k` for every call and taking a dependency
// the shell doesn't otherwise need. v1 costs nothing, covers on/off, brightness,
// hue/saturation and colour temperature, and gives "all lights" for free as the
// implicit group 0. What it doesn't give is a push event stream, hence polling.
//
// Polling only runs while something is looking: HuePopout sets `tracking` while
// it is open, and the timer is gated on it. With the panel closed this service
// makes no network requests at all — the only other traffic is the one-shot
// confirm fetch after a write the user explicitly asked for.
//
// v1 signals failures as [{"error":{...}}] with HTTP 200, so every response body
// has to be inspected even when the status looks fine. Two error types matter:
// 101 (link button not pressed) is the normal state during pairing, and 1
// (unauthorized user) means our saved credential has been revoked.

import QtQuick
import Quickshell
import qs.config

Singleton {
    id: root

    // ── Phase ───────────────────────────────────────────────────────────────

    property var bridges: []          // [{id, ip}] from the last discovery
    property bool discovering: false
    property bool pairing: false
    property bool fetching: false
    property string lastError: ""

    // "unconfigured" | "discovering" | "found" | "pairing" | "ready" | "error"
    //
    // `ready` is checked before `error` on purpose: once paired, a failed poll is
    // a transient the panel shows inline, not a reason to throw the user back to
    // the setup screen. Only losing the credential does that.
    readonly property string phase: {
        if (root.pairing)
            return "pairing";
        if (root.discovering)
            return "discovering";
        if (HueState.paired)
            return "ready";
        if (root.lastError !== "")
            return "error";
        if (root.bridges.length > 0)
            return "found";
        return "unconfigured";
    }

    // ── Lights ──────────────────────────────────────────────────────────────

    // The bridge's own `{ "1": {...}, "2": {...} }` map, exactly as last polled.
    property var raw: ({})

    // True until a fetch has ever succeeded, and again after one fails. It is
    // deliberately *not* set when the panel closes: the last successful reading is
    // still the best thing we know, and re-opening refetches it immediately. What
    // this flag prevents is the bar asserting "0 of 0 lights on" at login, before
    // the shell has ever spoken to the bridge.
    property bool stale: true

    // Set by HuePopout while it is open. Nothing polls unless this is true.
    property bool tracking: false

    readonly property var lights: {
        const out = [];
        for (const id in root.raw) {
            const entry = root.raw[id];
            if (entry && typeof entry === "object")
                out.push(root.describe(id, entry));
        }
        // By name, not by bridge id: the ids are assignment order, which means
        // nothing to anyone reading the list.
        out.sort((a, b) => a.name.localeCompare(b.name));
        return out;
    }

    readonly property var pinnedLights: root.lights.filter(l => HueState.isPinned(l.id))

    readonly property int onCount: root.lights.filter(l => l.on).length
    readonly property bool anyOn: root.onCount > 0

    readonly property int pinnedOnCount: root.pinnedLights.filter(l => l.on).length
    readonly property bool pinnedAnyOn: root.pinnedOnCount > 0

    // Average brightness across the lights that are on — what the master slider
    // shows. Lights that are off would drag it to zero and make the handle jump
    // as soon as one is switched off.
    readonly property real groupBri: {
        const lit = root.lights.filter(l => l.on && l.dimmable);
        if (lit.length === 0)
            return 0;
        return lit.reduce((sum, l) => sum + l.brightness, 0) / lit.length;
    }

    // Same, over just the pinned lights — what the Pinned tab's master row shows.
    readonly property real pinnedGroupBri: {
        const lit = root.pinnedLights.filter(l => l.on && l.dimmable);
        if (lit.length === 0)
            return 0;
        return lit.reduce((sum, l) => sum + l.brightness, 0) / lit.length;
    }

    function light(id) {
        return root.lights.find(l => l.id === String(id)) ?? null;
    }

    // Flattens a bridge light into what the UI actually binds to, with any
    // in-flight optimistic values layered on top. Capability flags come from
    // which keys the bridge reports in `state` rather than from the `type`
    // string — a plug reports no `bri`, a white ambiance bulb no `hue`.
    function describe(id, entry) {
        const s = entry.state ?? ({});
        const p = root.pending[id]?.patch ?? ({});
        const pick = key => p[key] !== undefined ? p[key] : s[key];

        const dimmable = s.bri !== undefined;
        const colourCapable = s.hue !== undefined && s.sat !== undefined;
        const ctCapable = s.ct !== undefined;
        const on = pick("on") === true;
        const bri = pick("bri") ?? 0;

        return {
            id: id,
            name: entry.name ?? `Light ${id}`,
            on: on,
            bri: bri,
            hue: pick("hue") ?? 0,
            sat: pick("sat") ?? 0,
            ct: pick("ct") ?? 300,
            // A light that is on but unreachable is one the bridge has lost, not
            // one that is off — say so rather than showing a stale brightness.
            reachable: s.reachable !== false,
            dimmable: dimmable,
            colourCapable: colourCapable,
            ctCapable: ctCapable,
            brightness: dimmable ? bri / 254 : (on ? 1 : 0),
            colour: root.swatch(pick, s.colormode, colourCapable, ctCapable)
        };
    }

    // The dot beside a light's name. Approximate on purpose — it is a 22px
    // circle, not a colour proof. xy mode is read through hue/sat because the
    // bridge keeps those updated whichever way the light was set.
    function swatch(pick, colormode, colourCapable, ctCapable) {
        if (ctCapable && (colormode === "ct" || !colourCapable))
            return root.ctColour(pick("ct") ?? 300);
        if (colourCapable)
            return Qt.hsva((pick("hue") ?? 0) / 65535, (pick("sat") ?? 0) / 254, 1, 1);
        return Qt.rgba(1, 0.87, 0.71, 1);
    }

    // Mireds run 153 (6500K, cool) to 500 (2000K, warm).
    function ctColour(mireds) {
        const t = Math.max(0, Math.min(1, (mireds - 153) / 347));
        return Qt.rgba(0.80 + 0.20 * t, 0.89 - 0.23 * t, 1.00 - 0.72 * t, 1);
    }

    // ── Discovery ───────────────────────────────────────────────────────────

    // Asks discovery.meethue.com which bridges it can see coming from this
    // network's public address. That endpoint has a real certificate, so unlike
    // the bridge itself it works with plain XMLHttpRequest.
    function discover() {
        root.bridges = [];
        root.lastError = "";

        if (!Config.hue.cloudDiscovery) {
            root.lastError = "Cloud discovery is turned off — enter the bridge address below";
            return;
        }

        root.discovering = true;
        root.request("GET", "https://discovery.meethue.com", null, parsed => {
            root.discovering = false;
            const found = (Array.isArray(parsed) ? parsed : []).filter(b => b && b.internalipaddress).map(b => ({
                        id: b.id ?? "",
                        ip: b.internalipaddress
                    }));
            root.bridges = found;
            if (found.length === 0)
                root.lastError = "No bridge found on this network";
        }, msg => {
            root.discovering = false;
            root.lastError = msg;
        });
    }

    // ── Pairing ─────────────────────────────────────────────────────────────

    property string pairIp: ""
    property string pairId: ""
    property int pairTicks: 0
    // The bridge's link button stays live for 30s; allow a little longer so a
    // user who presses it a beat late still gets in.
    readonly property int pairLimit: 45
    readonly property int pairRemaining: Math.max(0, root.pairLimit - root.pairTicks)

    function pair(ip, id) {
        if (!ip || ip === "")
            return;
        root.pairIp = ip;
        root.pairId = id ?? "";
        root.pairTicks = 0;
        root.lastError = "";
        root.pairing = true;
        root.attemptPair();
    }

    function cancelPair() {
        root.pairing = false;
        root.pairTicks = 0;
    }

    function attemptPair() {
        if (!root.pairing)
            return;
        // devicetype is "appname#devicename" and the bridge caps it at 40 chars,
        // so the whole thing is trimmed rather than letting the bridge reject it.
        const host = (SystemInfo.host && SystemInfo.host !== "") ? SystemInfo.host : "ionix";
        root.request("POST", `http://${root.pairIp}/api`, {
            devicetype: `ionix#${host}`.substring(0, 40)
        }, parsed => {
            const entry = (Array.isArray(parsed) ? parsed : []).find(e => e && e.success);
            const username = entry?.success?.username;
            if (!username) {
                // Success-shaped but no credential in it. Keep waiting rather than
                // failing — the retry timer will ask again.
                return;
            }
            root.pairing = false;
            root.stale = true;
            HueState.saveBridge(root.pairIp, root.pairId, username);
            root.refresh();
        }, (msg, err) => {
            // 101 is the expected answer until the button is pressed.
            if (err && err.type === 101)
                return;
            root.pairing = false;
            root.lastError = msg;
        });
    }

    Timer {
        running: root.pairing
        interval: 1000
        repeat: true
        onTriggered: {
            root.pairTicks++;
            if (root.pairTicks > root.pairLimit) {
                root.pairing = false;
                root.lastError = "Timed out waiting for the link button";
                return;
            }
            root.attemptPair();
        }
    }

    // Skip discovery and pair against a hand-entered address.
    function setBridge(ip) {
        const trimmed = (ip ?? "").trim();
        if (trimmed === "")
            return;
        root.pair(trimmed, "");
    }

    function forget() {
        root.cancelPair();
        root.raw = ({});
        root.pending = ({});
        root.queued = ({});
        root.bridges = [];
        root.lastError = "";
        root.stale = true;
        HueState.forget();
    }

    // ── Polling ─────────────────────────────────────────────────────────────

    readonly property string apiBase: `http://${HueState.bridgeIp}/api/${HueState.username}`

    function refresh() {
        if (!HueState.paired || root.fetching)
            return;
        root.fetching = true;
        root.request("GET", `${root.apiBase}/lights`, null, parsed => {
            root.fetching = false;
            if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
                root.lastError = "Bridge returned an unexpected light list";
                root.stale = true;
                return;
            }
            root.raw = parsed;
            root.stale = false;
            root.lastError = "";
            root.prune();
        }, (msg, err) => {
            root.fetching = false;
            root.stale = true;
            if (err && err.type === 1) {
                // The credential was deleted on the bridge. Drop it and fall back
                // to the setup screen rather than retrying forever.
                HueState.forget();
                root.lastError = "The bridge rejected our credential — pair again";
                return;
            }
            root.lastError = msg;
        });
    }

    // The only repeating timer in this service, and it does not run unless the
    // popout is open. triggeredOnStart so opening the panel fetches immediately
    // instead of showing a stale list for a whole interval.
    Timer {
        running: Config.hue.enabled && HueState.paired && root.tracking
        interval: Math.max(500, Config.hue.pollInterval ?? 2000)
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // ── Writes ──────────────────────────────────────────────────────────────

    // id → {patch, expires}: values we've sent that the bridge hasn't confirmed.
    // Layered over polled state by describe() so a poll landing mid-drag cannot
    // snap a slider back to a value the user has already moved past.
    property var pending: ({})

    // id (or "all"/"pinned") → patch waiting to be sent. The bridge rate-limits, and
    // StyledSlider.moved fires on every mouse move, so writes are coalesced.
    property var queued: ({})

    function setLight(id, patch) {
        root.enqueue(String(id), patch);
    }

    function setAll(patch) {
        root.enqueue("all", patch);
    }

    function toggle(id) {
        const l = root.light(id);
        if (l)
            root.setLight(id, {
                on: !l.on
            });
    }

    // Fraction (0..1) to the bridge's 1..254. Zero brightness is not a thing —
    // the bridge treats bri 0 as its dimmest lit state, not as off.
    function toBri(fraction) {
        return Math.max(1, Math.min(254, Math.round(fraction * 254)));
    }

    function setBrightness(id, fraction) {
        root.setLight(id, {
            on: true,
            bri: root.toBri(fraction)
        });
    }

    function setGroupBrightness(fraction) {
        root.setAll({
            on: true,
            bri: root.toBri(fraction)
        });
    }

    function stepGroupBrightness(direction) {
        const next = Math.max(0, Math.min(1, root.groupBri + direction * 0.05));
        root.setGroupBrightness(next);
    }

    // Applies a hex/QColor to a light as hue+saturation. White-ish picks are sent
    // as a colour temperature instead when the light supports one, because a
    // desaturated RGB white looks noticeably worse than the bulb's own white.
    function setColour(id, colour) {
        // "all" and "pinned" have no capabilities of their own — the bridge
        // applies what it can to each member, so a group target is treated as
        // capable of everything.
        const group = String(id) === "all" || String(id) === "pinned";
        const l = group ? null : root.light(id);
        if (!group && !l)
            return;

        const hsv = root.toHsv(Qt.color(colour));
        if (hsv.s < 0.12 && (group || l.ctCapable)) {
            root.setLight(id, {
                on: true,
                ct: 300
            });
            return;
        }
        if (!group && !l.colourCapable)
            return;
        root.setLight(id, {
            on: true,
            hue: Math.round(hsv.h * 65535) % 65536,
            sat: Math.round(hsv.s * 254)
        });
    }

    // QColor exposes hsvHue/hsvSaturation, but hsvHue is -1 for greys, which
    // would land as a bogus red once multiplied out.
    function toHsv(c) {
        const h = c.hsvHue < 0 ? 0 : c.hsvHue;
        return {
            h: h,
            s: c.hsvSaturation,
            v: c.hsvValue
        };
    }

    function enqueue(target, patch) {
        const q = Object.assign({}, root.queued);
        q[target] = Object.assign({}, q[target] ?? ({}), patch);
        root.queued = q;
        root.optimistic(target, patch);

        if (target === "all" || target === "pinned")
            groupSend.restart();
        else
            lightSend.restart();
    }

    function optimistic(target, patch) {
        // Long enough to cover a send plus the confirm fetch behind it; if the
        // bridge never agrees, the value falls back to reality instead of
        // sticking on screen forever.
        const expires = Date.now() + 2500;
        const next = Object.assign({}, root.pending);
        const ids = target === "all" ? Object.keys(root.raw) : target === "pinned" ? root.pinnedLights.map(l => l.id) : [target];
        for (const id of ids)
            next[id] = {
                patch: Object.assign({}, next[id]?.patch ?? ({}), patch),
                expires: expires
            };
        root.pending = next;
    }

    // Drops optimistic values the bridge has caught up on, or that have waited
    // long enough. Only reassigns `pending` when something actually changed —
    // `lights` is bound to it, so a fresh object every poll would rebuild every
    // row for nothing.
    function prune() {
        const now = Date.now();
        const next = {};
        let changed = false;

        for (const id in root.pending) {
            const entry = root.pending[id];
            const state = root.raw[id]?.state ?? ({});
            const remaining = {};
            let any = false;

            for (const key in entry.patch) {
                if (state[key] === entry.patch[key] || now > entry.expires) {
                    changed = true;
                    continue;
                }
                remaining[key] = entry.patch[key];
                any = true;
            }

            if (any)
                next[id] = {
                    patch: remaining,
                    expires: entry.expires
                };
            else
                changed = true;
        }

        if (changed)
            root.pending = next;
    }

    // Hue's guidance is roughly 10 light commands a second and one group command
    // a second; these intervals keep a hard slider drag inside both.
    Timer {
        id: lightSend
        interval: 120
        onTriggered: root.flushLights()
    }

    Timer {
        id: groupSend
        interval: 400
        onTriggered: root.flushGroup()
    }

    function flushLights() {
        const q = root.queued;
        const keep = {};
        for (const target in q) {
            if (target === "all" || target === "pinned") {
                keep[target] = q[target];
                continue;
            }
            root.send(`${root.apiBase}/lights/${target}/state`, q[target]);
        }
        root.queued = keep;
    }

    function flushGroup() {
        const all = root.queued["all"];
        const pinned = root.queued["pinned"];
        if (!all && !pinned)
            return;
        const keep = Object.assign({}, root.queued);
        delete keep["all"];
        delete keep["pinned"];
        root.queued = keep;
        if (all)
            root.send(`${root.apiBase}/groups/0/action`, all);
        // The bridge has no group holding the pinned set, so it fans out per
        // light — but on the group timer's cadence, so a slider drag doesn't
        // multiply into N lights × the per-light send rate.
        if (pinned)
            for (const l of root.pinnedLights)
                root.send(`${root.apiBase}/lights/${l.id}/state`, pinned);
    }

    function send(url, patch) {
        if (!HueState.paired)
            return;
        const body = Object.assign({}, patch);
        // transitiontime is in 100ms units.
        body.transitiontime = Math.max(0, Math.round((Config.hue.transitionTime ?? 300) / 100));
        root.request("PUT", url, body, () => {
            confirm.restart();
        }, (msg, err) => {
            if (err && err.type === 1) {
                HueState.forget();
                root.lastError = "The bridge rejected our credential — pair again";
                return;
            }
            root.lastError = msg;
        });
    }

    // One fetch shortly after a write settles, so the panel confirms the change
    // without needing a faster poll — and so a middle-click on the bar updates
    // the icon even though nothing is polling.
    Timer {
        id: confirm
        interval: 400
        onTriggered: root.refresh()
    }

    // ── HTTP ────────────────────────────────────────────────────────────────

    // onFail is called as (message, error) where `error` is the v1 error object
    // when the bridge sent one, and undefined for transport failures.
    function request(method, url, body, onOk, onFail) {
        const xhr = new XMLHttpRequest();

        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;

            // status 0 is the shape a refused connection or a bad address takes.
            if (xhr.status === 0) {
                onFail("Could not reach the bridge");
                return;
            }
            if (xhr.status < 200 || xhr.status >= 300) {
                onFail(`Bridge returned HTTP ${xhr.status}`);
                return;
            }

            let parsed;
            try {
                parsed = JSON.parse(xhr.responseText);
            } catch (e) {
                onFail("Bridge sent a response that isn't JSON");
                return;
            }

            const err = root.firstError(parsed);
            if (err) {
                onFail(root.errorText(err), err);
                return;
            }
            onOk(parsed);
        };

        xhr.open(method, url);
        if (body !== null && body !== undefined) {
            xhr.setRequestHeader("Content-Type", "application/json");
            xhr.send(JSON.stringify(body));
        } else {
            xhr.send();
        }
    }

    function firstError(parsed) {
        if (!Array.isArray(parsed))
            return null;
        for (const entry of parsed)
            if (entry && entry.error)
                return entry.error;
        return null;
    }

    function errorText(err) {
        if (err.type === 1)
            return "The bridge rejected our credential";
        if (err.type === 101)
            return "Press the link button on the bridge";
        if (err.type === 3)
            return "The bridge doesn't know about that light";
        return err.description ?? "The bridge reported an error";
    }
}
