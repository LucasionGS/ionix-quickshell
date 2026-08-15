pragma Singleton

// Which shell surfaces currently want keyboard input.
//
// The bar's layer surface has to advertise OnDemand keyboard interactivity for a
// popup of it to take keyboard focus — that is what lets the start menu's search
// field type, the Wi-Fi password field accept a paste, and Escape close a menu.
// But OnDemand also means Hyprland parks keyboard focus on the layer the moment
// anything on the bar is clicked, and it will not hand focus to a window that maps
// while a layer surface holds it. An app launched from the bar or the start menu
// therefore opens unfocused and stays that way until the pointer moves, because
// follow_mouse is then the only thing left that hands a window focus back.
//
// So the bar asks for OnDemand only while a popout or menu is actually open, and
// None the rest of the time. Registration is keyed off each surface's own focus
// grab rather than off Popouts, because the tray and taskbar menus are not
// popouts and need exactly the same thing.

import Quickshell

Singleton {
    id: root

    // The surfaces currently asking for keyboard focus.
    property var holders: []

    readonly property bool wanted: root.holders.length > 0

    // Keyed on the caller rather than counted, so a surface that re-asserts the
    // state it already has — or is destroyed while still open — cannot leave the
    // bar holding keyboard focus with nothing on screen to use it.
    function hold(holder, wants) {
        const at = root.holders.indexOf(holder);
        if (wants === (at >= 0))
            return;
        const next = root.holders.slice();
        if (wants)
            next.push(holder);
        else
            next.splice(at, 1);
        root.holders = next;
    }
}
