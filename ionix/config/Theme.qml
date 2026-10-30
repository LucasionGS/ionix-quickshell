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
    //
    // A theme may state any of these outright, as #AARRGGBB, when its design
    // language does not derive them the way the glass convention does, such as
    // neutral strokes rather than ones tinted with the accent.
    readonly property color barFill: c("barFill", alpha(bgDeep, Config.bar.opacity))
    readonly property color panelFill: c("panelFill", alpha(bgWindow, 0.88))
    readonly property color tooltipFill: c("tooltipFill", alpha(bgDeep, 0.94))
    readonly property color pillFill: c("pillFill", alpha(bgCard, 0.35))
    readonly property color pillBorder: c("pillBorder", alpha(border, 0.5))
    readonly property color barBorder: c("barBorder", alpha(accentBright, 0.18))
    readonly property color dockFill: c("dockFill", barFill)
    readonly property color panelBorder: c("panelBorder", alpha(accentBright, 0.25))
    readonly property color divider: c("divider", alpha(border, 0.35))

    // ── Design language ─────────────────────────────────────────────────────
    // Independent choices, so a theme takes what suits it.
    //
    // flat: controls that change colour rather than size, neutral strokes and hover
    // fills instead of accent-tinted ones, thin sliders and hollow switches.
    readonly property bool flat: Config.theme.flat === true
    // Gap between a panel and the bar and screen edge it opens from. 0 is the shell's
    // own placement: panels touch the bar and slide only as far as the screen needs.
    readonly property int flyoutGap: n("flyoutGap", 0)
    // Control surfaces: pointer-over and pressed fills, resting fill and stroke, a
    // text field's fill, and the strip along the bottom of a panel.
    readonly property color subtleHover: c("subtleHover", alpha(hover, 0.5))
    readonly property color subtlePressed: c("subtlePressed", alpha(hover, 0.35))
    readonly property color controlFill: c("controlFill", alpha(bgCard, 0.5))
    readonly property color controlStroke: c("controlStroke", alpha(border, 0.5))
    readonly property color fieldFill: c("fieldFill", alpha(bgDeep, 0.6))
    readonly property color footerFill: c("footerFill", alpha(bgDeep, 0.5))
    // Behind a Close control under the pointer.
    readonly property color closeHover: c("closeHover", red)
    readonly property color onAccent: c("onAccent", bgDeep)

    // ── Geometry ────────────────────────────────────────────────────────────
    readonly property int rSm: n("rSm", 8)
    readonly property int rPill: n("rPill", 12)
    readonly property int rBar: Config.bar.radius
    readonly property int rPanel: n("rPanel", 18)
    readonly property int rRound: 999

    readonly property int sp1: 2
    readonly property int sp2: 4
    readonly property int sp3: 8
    readonly property int sp4: 12
    readonly property int sp5: 16
    readonly property int sp6: 20
    readonly property int sp7: 28

    // Height of a pill sitting inside the bar, leaving a 6px inset top and bottom.
    readonly property int pillHeight: n("pillHeight", Math.max(20, Config.bar.height - 12))

    // ── Typography ──────────────────────────────────────────────────────────
    readonly property string fontFamily: s("fontFamily", "JetBrainsMono Nerd Font")
    readonly property string fontMono: s("fontMono", "JetBrainsMono Nerd Font")
    readonly property string fontLogo: s("fontLogo", "Ionix")

    readonly property int fsXs: n("fsXs", 9)
    readonly property int fsSm: n("fsSm", 11)
    readonly property int fsMd: n("fsMd", 12)
    readonly property int fsBase: n("fsBase", 13)
    readonly property int fsLg: n("fsLg", 14)
    readonly property int fsXl: n("fsXl", 16)
    readonly property int fsIcon: n("fsIcon", 16)
    readonly property int fsIconLg: n("fsIconLg", 20)
    readonly property int fsTitle: n("fsTitle", 22)

    // ── Motion ──────────────────────────────────────────────────────────────
    // Nothing in the shell animates for longer than durSlow. Hover uses OutBack for
    // a slight overshoot; anything that moves layout uses OutCubic so it settles.
    readonly property int durFast: n("durFast", 120)
    readonly property int durNormal: n("durNormal", 160)
    readonly property int durSlide: n("durSlide", 220)
    readonly property int durSlow: n("durSlow", 260)

    readonly property int easeStandard: Easing.OutCubic
    readonly property int easeOvershoot: flat ? Easing.OutCubic : Easing.OutBack
    // How far a hovered glyph grows. Flat controls change colour, never size.
    readonly property real hoverScale: flat ? 1.0 : 1.08
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

    function n(key, fallback) {
        const v = Config.theme[key];
        return typeof v === "number" ? v : fallback;
    }

    function s(key, fallback) {
        const v = Config.theme[key];
        return (typeof v === "string" && v !== "") ? v : fallback;
    }
}
