# ionix-quickshell

The Ionix desktop shell — a [Quickshell](https://quickshell.org) (QtQuick/QML) bar, popouts and
OSD, styled to the Ionix deep-purple theme.

Replaces waybar in [Ionix](https://github.com/LucasionGS/ionix-iso).

## What's in it

- **Bar** — floating, blurred, rounded. Workspaces with a sliding indicator, window taskbar,
  media widget, system tray, audio / network / bluetooth / battery indicators, clock, and a
  notification bell wired to swaync.
- **Start menu** — behind the logo button. Pinned tile grid, the apps you actually use, and a
  search that covers applications, **your open windows** (Enter raises the window instead of
  starting a second copy), shell actions like `dnd` / `wifi` / `lock`, and desktop themes.
- **Popouts** — calendar, audio mixer (with per-application volume sliders), Wi-Fi picker with
  inline password entry, bluetooth device manager, media player with album-art backdrop, and a
  power menu.
- **OSD** — volume and brightness, driven over IPC so the feedback is exact rather than polled.

## Install

```bash
# Arch (AUR)
yay -S ionix-quickshell-git

# From source
sudo make install
```

Then either:

```bash
systemctl --user enable --now ionix-quickshell
# or just run it
ionix-shell-qs
```

## Configuration

The shell ships its defaults to `/etc/xdg/quickshell/ionix/`. **Never edit those** — they belong
to the package and get overwritten on upgrade.

### Tier 1 — `config.json` (what you want 95% of the time)

Create `~/.config/quickshell/ionix/config.json`. It is deep-merged over the shipped defaults and
applied **live** — save the file and the bar restyles itself, no restart.

```jsonc
{
  "bar": {
    "height": 46,
    "position": "top",
    "floating": true,
    "radius": 16,
    "opacity": 0.82,
    "monitors": ["*"]
  },
  "modules": {
    "left":   ["Launcher", "Workspaces", "Taskbar"],
    "center": ["MediaWidget"],
    "right":  ["Tray", "AudioIndicator", "NetworkIndicator",
               "BluetoothIndicator", "BatteryIndicator", "Clock", "NotificationBell"]
  },
  "theme": { "accentBright": "#a855f7" },
  "clock": { "format": "HH:mm", "dateFormat": "ddd d MMM" }
}
```

Reordering, disabling and recolouring every module is reachable from here. See
`/etc/xdg/quickshell/ionix/defaults.json` for every key at its shipped value.

The start menu has its own block:

```jsonc
{
  "start": {
    "enabled": true,          // false gives the logo button back to launcher.command
    "width": 620,
    "maxHeightFraction": 0.72, // of the screen; past that the body scrolls
    "columns": 6,
    "showRunning": true,
    "recommend": "frequent",  // frequent | recent
    "defaultPins": ["kitty", "firefox", "code"]
  }
}
```

`defaultPins` is only a seed. The moment you pin or unpin anything the list moves to
`$XDG_STATE_HOME/ionix/quickshell/start.json`, which also holds the launch counts behind the
Frequent section — that file is the one thing the shell writes. Pins are desktop-entry ids
*without* the `.desktop` suffix, the same form a window's `app_id` resolves to; ids naming
something you haven't installed are skipped rather than drawn as empty tiles.

The theme picker in the footer only appears when `start.stylerBin` is runnable, so the menu is
unchanged on a non-Ionix system. It defaults to the absolute
`/usr/local/share/ionix/styler/bin/ionixtheme`.

> **Why `~/.config/quickshell/ionix/config.json` is safe:** Quickshell resolves a named config by
> looking for `<dir>/ionix/shell.qml` in each XDG config directory in turn. A directory containing
> only `config.json` has no `shell.qml`, so resolution falls through to `/etc/xdg` and the shipped
> shell still loads — it just reads your overrides.

### Tier 2 — `user.qml` (escape hatch)

If `~/.config/quickshell/ionix/user.qml` exists it is loaded into the shell. Use it to add your own
windows or widgets:

```qml
import QtQuick
import Quickshell

Scope {
    PanelWindow {
        anchors { bottom: true; left: true }
        implicitWidth: 200; implicitHeight: 40
        Text { anchors.centerIn: parent; text: "hi"; color: "#c4b5fd" }
    }
}
```

No compatibility guarantee — internals may change between releases.

### Tier 3 — fork it

```bash
ionix-shell-fork mine     # copies /etc/xdg/quickshell/ionix -> ~/.config/quickshell/mine
qs -c mine
```

Dropping your own `shell.qml` into `~/.config/quickshell/ionix/` also takes over completely, since
that directory then resolves before `/etc/xdg`.

## IPC

```bash
qs -c ionix ipc show                        # list handlers
qs -c ionix ipc call audio increase
qs -c ionix ipc call brightness decrease
qs -c ionix ipc call popout toggle calendar
qs -c ionix ipc call start toggle
qs -c ionix ipc call theme reload
```

Binding the volume/brightness keys to these instead of `wpctl`/`brightnessctl` gives the OSD exact
values with no polling. Keep a fallback so the keys still work when the shell is down:

```
bind = , XF86AudioRaiseVolume, exec, qs -c ionix ipc call audio increase || wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%+
```

## Development

```bash
# point the XDG config path at a checkout — quickshell hot-reloads on save
ln -s "$PWD/ionix" ~/.config/quickshell/ionix
qs -c ionix

make check    # launch for 12s, fail on any logged ERROR/WARN
make lint     # qmlformat — see the warning below
```

Errors report as `file:line`. There is no useful static type check — Quickshell's types aren't on a
standard `qmllint` import path — so the runtime is the only checker, and `make check` is the one
that matters.

> **`make lint` is not safe with every qmlformat.** Some versions rewrite `pragma Singleton` to sit
> *below* the imports, which is invalid, and hoist every inline comment to the top of the object it
> was written inside. Run it on a clean tree and read the diff before keeping it.

## Requirements

Quickshell ≥ 0.3.0, a Wayland compositor with `wlr-layer-shell` (Hyprland recommended — workspace
and window integration are Hyprland-specific), PipeWire, NetworkManager, BlueZ, UPower.

## Licence

MIT
