pragma Singleton

// Nerd Font glyph tables and the pure functions that pick between them.
// Kept separate from Theme so restyling and re-iconing are independent concerns.

import Quickshell
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import Quickshell.Networking

Singleton {
    id: root

    // ── Static glyphs ───────────────────────────────────────────────────────
    readonly property string logo: ""
    readonly property string bell: "󰂚"
    readonly property string bellDnd: "󰂛"
    readonly property string calendar: "󰃭"
    readonly property string ethernet: "󰈀"
    readonly property string wifiOff: "󰤫"
    readonly property string disconnected: "󰖪"
    readonly property string lock: "󰌾"
    readonly property string logout: "󰍃"
    readonly property string suspend: "󰤄"
    readonly property string hibernate: "󰋊"
    readonly property string reboot: "󰜉"
    readonly property string shutdown: "󰐥"
    readonly property string prev: "󰒮"
    readonly property string next: "󰒭"
    readonly property string play: "󰐊"
    readonly property string pause: "󰏤"
    readonly property string music: "󰝚"
    readonly property string shuffle: "󰒝"
    readonly property string shuffleOn: "󰒟"
    readonly property string loopNone: "󰑗"
    readonly property string loopTrack: "󰑘"
    readonly property string loopList: "󰑖"
    readonly property string charging: "󱐋"
    readonly property string brightness: "󰃟"
    readonly property string search: "󰍉"
    readonly property string refresh: "󰑐"
    readonly property string check: "󰄬"
    readonly property string close: "󰅖"
    readonly property string chevronLeft: "󰅁"
    readonly property string chevronRight: "󰅂"
    readonly property string settings: "󰒓"
    readonly property string speaker: "󰓃"
    readonly property string microphone: "󰍬"
    readonly property string apps: "󰀻"
    readonly property string grid: "󰕰"
    readonly property string account: "󰀄"
    readonly property string palette: "󰏘"
    readonly property string pin: "󰐃"
    readonly property string pinOff: "󰤰"
    readonly property string history: "󰋚"
    readonly property string frequent: "󰈸"
    readonly property string window: "󰖯"
    readonly property string powerSaver: "󰌪"
    readonly property string balanced: "󰾅"
    readonly property string performance: "󰓅"

    // ── Workspaces ──────────────────────────────────────────────────────────
    readonly property string wsActive: "󰮯"
    readonly property string wsOccupied: "󰊠"
    readonly property string wsEmpty: "󰝦"
    readonly property string wsUrgent: "󰀦"

    // ── Volume ──────────────────────────────────────────────────────────────
    readonly property var volumeRamp: ["󰕿", "󰖀", "󰕾"]

    function volume(level, muted, portType) {
        if (muted)
            return "󰖁";
        if (portType === "headphone")
            return "󰋋";
        if (portType === "headset")
            return "󰋎";
        if (level <= 0.001)
            return "󰕿";
        const i = Math.min(volumeRamp.length - 1, Math.floor(level * volumeRamp.length));
        return volumeRamp[i];
    }

    function microphoneIcon(muted) {
        return muted ? "󰍭" : "󰍬";
    }

    // ── Battery ─────────────────────────────────────────────────────────────
    readonly property var batteryRamp: ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]

    function battery(percent, charging) {
        if (charging)
            return "󰂄";
        const i = Math.max(0, Math.min(batteryRamp.length - 1, Math.round(percent / 100 * (batteryRamp.length - 1))));
        return batteryRamp[i];
    }

    // ── Network ─────────────────────────────────────────────────────────────
    readonly property var wifiRamp: ["󰤟", "󰤢", "󰤥", "󰤨"]

    // `strength` is a 0..1 fraction — that is what WifiNetwork.signalStrength
    // reports, despite reading like a percentage.
    function wifi(strength) {
        const i = Math.max(0, Math.min(wifiRamp.length - 1, Math.floor(strength * wifiRamp.length)));
        return wifiRamp[i];
    }

    function security(type) {
        return type === WifiSecurityType.Open ? "" : "󰌾";
    }

    // ── Bluetooth ───────────────────────────────────────────────────────────
    function bluetooth(enabled, connectedCount) {
        if (!enabled)
            return "󰂲";
        return connectedCount > 0 ? "󰂱" : "󰂯";
    }

    // Map BlueZ's icon hints onto glyphs. BlueZ reports freedesktop icon names,
    // which don't exist in a Nerd Font, so translate the common ones by hand.
    function bluetoothDevice(icon) {
        const i = (icon || "").toLowerCase();
        if (i.includes("headset") || i.includes("headphone"))
            return "󰋋";
        if (i.includes("audio") || i.includes("speaker"))
            return "󰓃";
        if (i.includes("phone"))
            return "󰄜";
        if (i.includes("mouse"))
            return "󰍽";
        if (i.includes("keyboard"))
            return "󰌌";
        if (i.includes("computer"))
            return "󰟀";
        if (i.includes("watch"))
            return "󰖉";
        if (i.includes("gaming") || i.includes("joypad"))
            return "󰊴";
        if (i.includes("printer"))
            return "󰐪";
        if (i.includes("camera"))
            return "󰄀";
        return "󰂯";
    }

    // ── Power profiles ──────────────────────────────────────────────────────
    function powerProfile(profile) {
        if (profile === PowerProfile.PowerSaver)
            return powerSaver;
        if (profile === PowerProfile.Performance)
            return performance;
        return balanced;
    }
}
