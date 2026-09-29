// The lock's per-monitor surface: an ext-session-lock surface hosting LockView.
// The greeter has no session-lock (it runs under cage) and hosts LockView in an
// ordinary window instead.

import Quickshell.Wayland
import qs.config

WlSessionLockSurface {
    id: surface

    color: Theme.bgDeep

    LockView {
        anchors.fill: parent
        screen: surface.screen
    }
}
