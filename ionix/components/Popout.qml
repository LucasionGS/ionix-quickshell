// A dismissable panel anchored under a bar item.
//
// Dismissal uses HyprlandFocusGrab, which is what makes click-outside work on a
// layer-shell surface — there is no "outside" MouseArea to catch on a compositor
// where the popup is its own window.
//
// The window stays mapped for durFast after `shouldOpen` drops so the exit
// animation has something to play on; closeHold is what keeps it alive.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.services

PopupWindow {
    id: root

    default property alias content: panel.content
    property Item anchorItem: null
    property bool shouldOpen: false
    property int panelWidth: 340
    property int padding: Theme.sp6
    // A picture behind the content; see GlassPanel.
    property alias backdrop: panel.backdrop
    property alias backdropDim: panel.backdropDim
    property alias bare: panel.bare

    // Where on the screen a panel from a horizontal bar goes. "" lines it up with its
    // anchor, "center" with the middle of the screen, "right" with the right-hand edge.
    // A vertical bar keeps its panels beside the anchor whatever this says.
    property string screenAlign: ""
    // Theme.flyoutGap, or the shell's usual small gap for a panel placed on the screen
    // under a theme that does not state one.
    readonly property int flyoutGap: Theme.flyoutGap > 0 ? Theme.flyoutGap : Theme.sp2
    readonly property bool barAtBottom: Config.bar.position === "bottom"
    readonly property bool placedOnScreen: !root.sideways && root.screenAlign !== ""
    // Opens away from the bar by a stated gap, instead of relying on FlipY.
    readonly property bool gapped: !root.sideways && (Theme.flyoutGap > 0 || root.screenAlign !== "")
    readonly property bool upward: root.gapped && root.barAtBottom

    // The bar item's own offset within its surface. A function, not a binding, for
    // the reason Placement gives: mapToItem() notifies nothing.
    property real anchorDx: 0
    property real anchorDy: 0
    function place() {
        if (!root.anchorItem || !root.gapped)
            return;
        const at = root.anchorItem.mapToItem(null, 0, 0);
        const width = root.screen?.width ?? 0;
        if (root.screenAlign === "center")
            root.anchorDx = width / 2 - at.x;
        else if (root.screenAlign === "right")
            root.anchorDx = width - root.flyoutGap - at.x;
        // From the item's edge to the bar's far edge, then the gap beyond it.
        const itemHeight = root.anchorItem.height;
        root.anchorDy = root.barAtBottom ? -at.y - root.flyoutGap : Config.bar.height - at.y - itemHeight + root.flyoutGap;
        root.anchor.updateAnchor();
    }

    // How tall a growing list inside a panel may get before it scrolls instead.
    // Half the screen, so no popout can swallow the desktop however many wi-fi
    // networks or bluetooth devices happen to be in range.
    //
    // Measured from the *screen*, never from the panel: GlassPanel sizes itself
    // from childrenRect and this window binds implicitHeight to that, so anything
    // in here deriving its height from the panel would close the loop.
    readonly property int maxContentHeight: Math.round((root.screen?.height ?? 1080) * 0.5)

    // Beside the bar item rather than below it when the bar is vertical, or the
    // panel would open across the modules above and below its anchor.
    readonly property bool sideways: Config.barVertical

    // Screen-space y of this panel's top edge, for anything inside that needs to
    // know where on the monitor it ended up — tooltips flip around the halfway
    // line, and a footer button in a tall panel is nowhere near its anchor.
    //
    // This has to mirror the FlipY below rather than read the result of it: the
    // compositor moves the surface above the anchor when it would not fit under
    // it, and never tells us that it did. The flipped placement was measured
    // rather than guessed — xdg-positioner mirrors the anchor edge but not the
    // offset, so the flipped panel's *bottom* lands on the anchor's top edge
    // pushed *down* by the same margin, not up by it.
    //
    // Sideways is the easier case: the panel's top starts level with the anchor's
    // and SlideY only ever pushes it back onto the screen, which is the same
    // clamp written out here.
    function screenTop() {
        const anchorTop = Placement.screenTop(root.anchorItem);
        if (anchorTop < 0)
            return -1;
        if (root.sideways)
            return Math.max(0, Math.min(anchorTop, (root.screen?.height ?? 0) - root.implicitHeight));
        if (root.upward)
            return anchorTop + root.anchorDy - root.implicitHeight;
        if (root.gapped)
            return anchorTop + root.anchor.rect.height;
        const below = anchorTop + (root.anchorItem?.height ?? 0) + Theme.sp2;
        if (below + root.implicitHeight <= (root.screen?.height ?? 0))
            return below;
        return anchorTop + Theme.sp2 - root.implicitHeight;
    }

    visible: root.shouldOpen || closeHold.running
    color: "transparent"
    // Take keyboard focus so Escape and text fields work inside the panel. The bar
    // only advertises keyboard interactivity while a surface says it wants it, so
    // saying so here is what makes that focus arrive at all.
    grabFocus: root.shouldOpen
    onGrabFocusChanged: ShellFocus.hold(root, root.grabFocus)
    Component.onDestruction: ShellFocus.hold(root, false)

    anchor.item: root.anchorItem
    readonly property int openEdge: root.gapped ? (root.barAtBottom ? Edges.Top : Edges.Bottom) : Config.barPopupEdge
    anchor.gravity: root.placedOnScreen && root.screenAlign === "right" ? root.openEdge | Edges.Left : root.openEdge
    anchor.edges: root.openEdge
    // The rect is relative to anchorItem. A width of 1 turns its top edge into the
    // point the panel hangs from when it is placed on the screen; otherwise the
    // item's own width applies, as it does with the rect left alone.
    anchor.rect.x: root.placedOnScreen ? root.anchorDx : 0
    anchor.rect.y: root.upward ? root.anchorDy : 0
    anchor.rect.width: root.placedOnScreen ? 1 : (root.anchorItem?.width ?? 0)
    // Downward, the rect grows to reach past the bar: it is its bottom edge that counts.
    anchor.rect.height: (root.anchorItem?.height ?? 0) + (root.gapped && !root.barAtBottom ? root.anchorDy : 0)
    anchor.margins.top: (root.sideways || root.gapped) ? 0 : Theme.sp2
    anchor.margins.left: Config.barPopupEdge === Edges.Right ? Theme.sp2 : 0
    anchor.margins.right: Config.barPopupEdge === Edges.Left ? Theme.sp2 : 0
    // Slide back onto the screen instead of overflowing when a right-hand module
    // opens a panel wider than the space left beside it.
    anchor.adjustment: root.sideways ? (PopupAdjustment.SlideY | PopupAdjustment.FlipX) : (root.gapped ? PopupAdjustment.SlideX : (PopupAdjustment.SlideX | PopupAdjustment.FlipY))

    implicitWidth: root.panelWidth
    implicitHeight: panel.implicitHeight

    onShouldOpenChanged: {
        if (!root.shouldOpen)
            closeHold.restart();
        else
            root.place();
    }

    Timer {
        id: closeHold
        interval: Theme.durFast
    }


    // Dismissal must go through Popouts, never through `shouldOpen = false`:
    // callers bind shouldOpen to Popouts.isOpen(...), and assigning to it would
    // overwrite that binding with a constant. The panel would then close once and
    // never reopen, because nothing re-evaluates when Popouts.current changes.
    HyprlandFocusGrab {
        active: root.shouldOpen
        windows: [root]
        onCleared: Popouts.close()
    }

    GlassPanel {
        id: panel
        width: root.panelWidth
        padding: root.padding

        opacity: root.shouldOpen ? 1 : 0
        scale: root.shouldOpen ? 1 : 0.94
        // Grows out of the edge it is anchored to, so the entry reads as the panel
        // coming out of the bar rather than dropping onto it from nowhere.
        y: root.shouldOpen || root.sideways ? 0 : 8
        x: root.shouldOpen || !root.sideways ? 0 : (Config.barPopupEdge === Edges.Right ? -8 : 8)
        transformOrigin: root.sideways ? (Config.barPopupEdge === Edges.Right ? Item.Left : Item.Right) : (root.upward ? Item.Bottom : Item.Top)

        Behavior on x {
            NumberAnimation {
                duration: root.shouldOpen ? Theme.durSlide : Theme.durFast
                easing.type: root.shouldOpen ? Theme.easeStandard : Theme.easeIn
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: root.shouldOpen ? Theme.durSlide : Theme.durFast
                easing.type: root.shouldOpen ? Theme.easeStandard : Theme.easeIn
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: root.shouldOpen ? Theme.durSlide : Theme.durFast
                easing.type: root.shouldOpen ? Theme.easeStandard : Theme.easeIn
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: root.shouldOpen ? Theme.durSlide : Theme.durFast
                easing.type: root.shouldOpen ? Theme.easeStandard : Theme.easeIn
            }
        }
    }

    // Set while something inside wants Escape for itself (an edit field it
    // cancels): a Shortcut fires before the focused item ever sees the key.
    property bool holdEscape: false

    Shortcut {
        sequence: "Escape"
        enabled: root.shouldOpen && !root.holdEscape
        onActivated: Popouts.close()
    }
}
