pragma Singleton

// Where an item actually sits on its monitor.
//
// Wayland will not tell us: an item's mapToGlobal() comes back window-relative
// because a layer-shell surface has no position of its own, PopupWindow.relativeY
// stays 0 whenever the popup is anchored rather than placed by hand, and
// windowTransform is null. So the position is reconstructed from the two things
// this shell does know — a PanelWindow's anchors and margins, which *are* measured
// from the screen edges, and a Popout's own placement rule.
//
// Everything here is a function rather than a property so callers get a fresh
// answer. A binding would capture only the properties it happened to read, and
// mapToItem() is not one of them, so a moved item would never be noticed.
//
// -1 means "could not work it out" rather than 0, so a caller can tell that apart
// from "at the very top of the screen" and fall back instead of guessing wrong.

import QtQuick
import Quickshell

Singleton {
    id: root

    // Screen-space y of an item's top edge.
    function screenTop(item) {
        if (!item)
            return -1;
        const win = item.QsWindow?.window;
        if (!win)
            return -1;
        const base = root.windowTop(win);
        if (base < 0)
            return -1;
        // mapToItem(null) resolves against the window's content item, which sits
        // at the window origin — so this is the offset within the surface.
        return base + item.mapToItem(null, 0, 0).y;
    }

    // Screen-space y of an item's vertical centre.
    function screenCentre(item) {
        const top = root.screenTop(item);
        return top < 0 ? -1 : top + (item.height ?? 0) / 2;
    }

    // True when the item is past the halfway line of the monitor it is on.
    // False when the position is unknown, so callers keep their default layout.
    function inLowerHalf(item) {
        const height = item?.QsWindow?.window?.screen?.height ?? 0;
        if (height <= 0)
            return false;
        const centre = root.screenCentre(item);
        return centre >= 0 && centre > height / 2;
    }

    // Screen-space y of a window's top edge.
    function windowTop(win) {
        // A Popout already has to work its own placement out — it mirrors the
        // compositor's flip — so take its answer instead of redoing it here.
        if (typeof win.screenTop === "function")
            return win.screenTop();
        // PanelWindow. anchors and margins are relative to the screen edges,
        // which is exactly the frame we want. Anchored top and bottom at once
        // means the surface is stretched, so the top margin still gives the top.
        //
        // Assumes the shell's own bar is the only surface reserving space on that
        // edge, which is the normal case — a second exclusive layer surface would
        // push this one inwards by its zone and there is no way to read that back.
        // The cost of being wrong is a tooltip picking the other side for a target
        // near the middle of the screen, which FlipY still keeps on screen.
        if (win.anchors !== undefined)
            return win.anchors.top ? win.margins.top : (win.screen?.height ?? 0) - win.margins.bottom - win.height;
        // A plain PopupWindow (menus, tooltips). Nothing readable to go on.
        return -1;
    }
}
