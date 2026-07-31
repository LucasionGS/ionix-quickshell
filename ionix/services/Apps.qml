pragma Singleton

// Installed applications, for the start menu.
//
// Windows.qml also touches DesktopEntries, but only ever backwards — from a
// window to the entry that spawned it. This is the forward direction: the list
// itself, ranked, and launched.

import QtQuick
import Quickshell
import qs.config

Singleton {
    id: root

    // `applications` is an UntypedObjectModel; its `values` is a QObjectList,
    // array-like but not guaranteed to carry the Array prototype, so copy it out
    // before doing anything JS to it. Same caveat as Windows.actionsFor.
    readonly property var list: {
        const values = DesktopEntries.applications.values;
        const out = [];
        for (let i = 0; i < values.length; i++) {
            const entry = values[i];
            if (entry && !entry.noDisplay)
                out.push(entry);
        }
        return out.sort((a, b) => (a.name ?? "").localeCompare(b.name ?? ""));
    }

    // The freedesktop main categories worth showing, in the order the menu lists
    // them. Anything an entry declares beyond these is ignored — .desktop files
    // carry a long tail of vendor categories that would make a useless rail.
    readonly property var categoryNames: ["Development", "Graphics", "AudioVideo", "Network", "Office", "Game", "Education", "Science", "Utility", "System", "Settings"]

    readonly property var categoryLabels: ({
            AudioVideo: "Media",
            Network: "Internet",
            Game: "Games",
            Utility: "Utilities"
        })

    // Only the categories that actually have something in them, so the rail never
    // offers a filter that yields an empty list.
    readonly property var categories: {
        const seen = ({});
        for (const entry of root.list) {
            for (const name of root.categoriesOf(entry))
                seen[name] = true;
        }
        return root.categoryNames.filter(name => seen[name] === true);
    }

    function label(category) {
        return root.categoryLabels[category] ?? category;
    }

    function categoriesOf(entry) {
        const declared = entry?.categories;
        if (!declared)
            return [];
        const out = [];
        for (let i = 0; i < declared.length; i++) {
            if (root.categoryNames.indexOf(declared[i]) !== -1)
                out.push(declared[i]);
        }
        return out;
    }

    function inCategory(entry, category) {
        return category === "" || root.categoriesOf(entry).indexOf(category) !== -1;
    }

    // ── Matching ────────────────────────────────────────────────────────────

    // How well a single string answers a query, 0 for not at all. Tiered rather
    // than a single distance metric so the ordering is explicable: an exact name
    // always beats a prefix, which always beats a word start, and a scattered
    // subsequence match is the last resort.
    function matchScore(text, query) {
        if (!text || text === "")
            return 0;
        const t = text.toLowerCase();
        if (t === query)
            return 100;
        if (t.startsWith(query))
            return 90;
        const words = t.split(/[\s\-_.:]+/);
        for (const word of words) {
            if (word.startsWith(query))
                return 78;
        }
        const at = t.indexOf(query);
        if (at !== -1)
            return 64 - Math.min(20, at);

        // Subsequence: every query character in order, penalised by how scattered
        // they are, so "fx" still finds Firefox but ranks below anything literal.
        let q = 0;
        let gaps = 0;
        for (let i = 0; i < t.length && q < query.length; i++) {
            if (t[i] === query[q])
                q++;
            else if (q > 0)
                gaps++;
        }
        return q === query.length ? Math.max(12, 40 - gaps) : 0;
    }

    // Best match across everything an entry can be known by. The name dominates;
    // the rest are weighted down so a keyword hit never outranks a title hit.
    function score(entry, query) {
        const q = query.toLowerCase().trim();
        if (q === "" || !entry)
            return 0;

        let best = root.matchScore(entry.name, q);
        best = Math.max(best, root.matchScore(entry.genericName, q) * 0.8);
        best = Math.max(best, root.matchScore(entry.id, q) * 0.6);

        const keywords = entry.keywords;
        if (keywords) {
            for (let i = 0; i < keywords.length; i++)
                best = Math.max(best, root.matchScore(keywords[i], q) * 0.7);
        }

        // Comment last and heavily discounted: it is a sentence, so a substring
        // hit there means much less than one in a name.
        best = Math.max(best, root.matchScore(entry.comment, q) * 0.35);
        return best;
    }

    // ── Presentation ────────────────────────────────────────────────────────

    // Same fallback chain as Windows.iconFor: an empty result means "draw your own
    // placeholder", because the icon provider paints a missing-texture
    // checkerboard for a name the theme doesn't have.
    function iconFor(entry) {
        if (!entry)
            return "";
        if (entry.icon && Quickshell.hasThemeIcon(entry.icon))
            return entry.icon;
        if (entry.icon && entry.icon.startsWith("/"))
            return entry.icon;
        const id = entry.id ?? "";
        if (id !== "" && Quickshell.hasThemeIcon(id))
            return id;
        return "";
    }

    function iconSource(entry) {
        const name = root.iconFor(entry);
        return name === "" ? "" : Quickshell.iconPath(name, true);
    }

    function subtitleFor(entry) {
        const generic = entry?.genericName ?? "";
        if (generic !== "" && generic !== entry?.name)
            return generic;
        return entry?.comment ?? "";
    }

    // Entry ids here carry no ".desktop" suffix — they are what a window's app_id
    // resolves to. Pins written by hand are the likely source of a suffixed id, so
    // strip it rather than silently dropping the tile.
    //
    // The scan over `list` is not just a convenience. DesktopEntries.byId is a
    // method, and a binding that only calls methods registers no dependency, so it
    // would never re-run — and the entry scan finishes *after* the shell loads, so
    // every pin resolved to null once and stayed blank. Reading `list` is what
    // makes anything bound to this function correct itself when the scan lands.
    function byId(id) {
        if (!id || id === "")
            return null;
        const bare = id.endsWith(".desktop") ? id.slice(0, -8) : id;
        for (const entry of root.list) {
            if (entry.id === bare)
                return entry;
        }
        return DesktopEntries.byId(bare) ?? DesktopEntries.heuristicLookup(bare);
    }

    // ── Launching ───────────────────────────────────────────────────────────

    function launch(entry) {
        if (!entry)
            return;
        StartState.recordLaunch(entry.id);
        entry.execute();
    }

    // The entry's own Actions= list, in the shape the menus want. Identical in
    // spirit to Windows.menuFor, but keyed off the entry rather than a window.
    function actionItems(entry) {
        const actions = entry?.actions;
        const out = [];
        if (!actions)
            return out;
        for (let i = 0; i < actions.length; i++) {
            const action = actions[i];
            out.push({
                text: action.name,
                icon: action.icon ?? "",
                trigger: () => {
                    StartState.recordLaunch(entry.id);
                    action.execute();
                }
            });
        }
        return out;
    }
}
