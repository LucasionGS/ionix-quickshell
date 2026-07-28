pragma Singleton

// Ionix visual theme — deep purple/violet dark.
//
// Every value reads through Config.theme so a user's config.json can override any
// of them, and because these are QML bindings the override propagates live to
// every widget without a restart.

import QtQuick
import Quickshell

Singleton {
    id: root

    // ── Core palette ────────────────────────────────────────────────────────
    readonly property color bgDeep: c("bgDeep", "#0f0a18")        // deepest layer, terminal bg
    readonly property color bgWindow: c("bgWindow", "#1a1025")    // bar, menus, popovers
    readonly property color bgCard: c("bgCard", "#2d2d3f")        // buttons, cards, input fills
    readonly property color hover: c("hover", "#3a2d50")          // hover state
    readonly property color border: c("border", "#4a3d60")        // borders, dividers, dim text
    readonly property color muted: c("muted", "#6b5f80")          // secondary text, passive icons
    readonly property color text: c("text", "#c4b5fd")            // default UI text
    readonly property color textBright: c("textBright", "#e2d9f3") // headings, input text
    readonly property color accent: c("accent", "#9b59b6")        // sliders, switches
    readonly property color accentBright: c("accentBright", "#a855f7") // active items
    readonly property color accentLight: c("accentLight", "#c084fc")   // icons, labels, glows

    // ── Semantic ────────────────────────────────────────────────────────────
    readonly property color green: c("green", "#2ecc71")
    readonly property color orange: c("orange", "#f39c12")
    readonly property color red: c("red", "#e74c3c")
    readonly property color cyan: c("cyan", "#48dbfb")
    readonly property color link: c("link", "#7c3aed")

    // ── Derived surfaces ────────────────────────────────────────────────────
    // Glass convention (CLAUDE.md): heavy for bars, medium for drawers, light for
    // tooltips. Always tinted with the deep backgrounds rather than solid fills.
    readonly property color barFill: alpha(bgDeep, Config.bar.opacity)
    readonly property color panelFill: alpha(bgWindow, 0.88)
    readonly property color tooltipFill: alpha(bgDeep, 0.94)
    readonly property color pillFill: alpha(bgCard, 0.35)
    readonly property color pillBorder: alpha(border, 0.5)
    readonly property color barBorder: alpha(accentBright, 0.18)
    readonly property color panelBorder: alpha(accentBright, 0.25)
    readonly property color divider: alpha(border, 0.35)

    // ── Geometry ────────────────────────────────────────────────────────────
    readonly property int rSm: 8
    readonly property int rPill: 12
    readonly property int rBar: Config.bar.radius
    readonly property int rPanel: 18
    readonly property int rRound: 999

    readonly property int sp1: 2
    readonly property int sp2: 4
    readonly property int sp3: 8
    readonly property int sp4: 12
    readonly property int sp5: 16
    readonly property int sp6: 20
    readonly property int sp7: 28

    // Height of a pill sitting inside the bar, leaving a 6px inset top and bottom.
    readonly property int pillHeight: Math.max(20, Config.bar.height - 12)

    // ── Typography ──────────────────────────────────────────────────────────
    readonly property string fontFamily: s("fontFamily", "JetBrainsMono Nerd Font")
    readonly property string fontMono: s("fontMono", "JetBrainsMono Nerd Font")
    readonly property string fontLogo: s("fontLogo", "Ionix")

    readonly property int fsXs: 9
    readonly property int fsSm: 11
    readonly property int fsMd: 12
    readonly property int fsBase: 13
    readonly property int fsLg: 14
    readonly property int fsXl: 16
    readonly property int fsIcon: 16
    readonly property int fsIconLg: 20
    readonly property int fsTitle: 22

    // ── Motion ──────────────────────────────────────────────────────────────
    // Nothing in the shell animates for longer than durSlow. Hover uses OutBack for
    // a slight overshoot; anything that moves layout uses OutCubic so it settles.
    readonly property int durFast: 120
    readonly property int durNormal: 160
    readonly property int durSlide: 220
    readonly property int durSlow: 260

    readonly property int easeStandard: Easing.OutCubic
    readonly property int easeOvershoot: Easing.OutBack
    readonly property int easeIn: Easing.InCubic

    // ── Helpers ─────────────────────────────────────────────────────────────

    // Same colour at a different opacity. Qt.rgba wants 0-1 components, and
    // Qt.alpha()/Qt.tint() don't do what we want here, so build it by hand.
    function alpha(colour, a) {
        return Qt.rgba(colour.r, colour.g, colour.b, a);
    }

    // Blend two colours; t=0 returns a, t=1 returns b.
    function mix(a, b, t) {
        const k = Math.max(0, Math.min(1, t));
        return Qt.rgba(a.r + (b.r - a.r) * k, a.g + (b.g - a.g) * k, a.b + (b.b - a.b) * k, a.a + (b.a - a.a) * k);
    }

    // Battery/level colour ramp: green above 30%, orange to 15%, red below.
    function levelColour(fraction) {
        if (fraction > 0.3)
            return green;
        if (fraction > 0.15)
            return orange;
        return red;
    }

    function c(key, fallback) {
        const v = Config.theme[key];
        return (v !== undefined && v !== null && v !== "") ? v : fallback;
    }

    function s(key, fallback) {
        const v = Config.theme[key];
        return (typeof v === "string" && v !== "") ? v : fallback;
    }
}
