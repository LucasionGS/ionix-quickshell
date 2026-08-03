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
- **Philips Hue** — opt-in. Finds and pairs a bridge from the bar, then gives every light
  on/off, brightness, colour and colour temperature, plus the same for all lights at once.
  Pin the ones you actually use; the panel opens on them.
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

### Tier 0 — the settings page (no file editing at all)

Open the start menu and click the gear in the footer. It has switches for the handful of things
worth toggling casually — the Hue, network and bluetooth bar modules, notification popups, and
the on-screen display — and they take effect immediately.

Those switches write `~/.config/quickshell/ionix/settings.json`, which is the **only** file this
shell writes. It merges *under* `config.json`, so anything you set by hand still wins; when it
does, the settings page shows that row greyed out and marked *Pinned by config.json* instead of
offering a switch that would do nothing. Hand-edits to `settings.json` need a shell reload
(`qs -c ionix ipc call theme reload`) since, unlike the other two, it isn't watched.

The full merge order, lowest priority first:
`defaults` → `theme.json` (ionix-settheme) → `settings.json` (settings page) → `config.json` (you).

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
    "right":  ["Tray", "AudioIndicator", "NetworkIndicator", "BluetoothIndicator",
               "HueIndicator", "BatteryIndicator", "Clock", "NotificationBell"]
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

Philips Hue is shipped in the module list but switched off, so it costs nothing until you want it:

```jsonc
{
  "hue": {
    "enabled": true,         // the only key you normally need
    "cloudDiscovery": true,  // false skips discovery.meethue.com; enter the IP by hand instead
    "pollInterval": 2000,    // only ever polls while the popout is open
    "transitionTime": 300,   // ms the bridge fades a change over
    "presets": ["#ff4d4d", "#ffd166", "#2ecc71", "#48dbfb", "#c084fc"]
  }
}
```

`enabled` is also the gear-icon settings page in the start menu — that is the easy way to turn it
on. Turn it on and a bulb appears in the bar; clicking it walks you through finding a bridge and
pressing its link button. The address and the credential the bridge issues are **not** stored
here — they go to `$XDG_STATE_HOME/ionix/quickshell/hue.json` along with your pinned lights,
because `config.json` is read-only as far as the shell is concerned. That directory is created
mode 700, since the credential drives your lights to anyone who has it.

Middle-click the bulb for all-off, scroll it for group brightness. Right-click a light in the
list to pin it. Lights are only polled while the panel is open — with it closed the shell makes
no requests to the bridge at all, so the bar shows the last reading it took.

It speaks the CLIP v1 API over plain HTTP. v2 is HTTPS-only behind a self-signed certificate that
QML's `XMLHttpRequest` cannot be told to accept, which would mean shelling out to `curl -k` for
every call; v1 needs no dependency and covers everything here.

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
qs -c ionix ipc call hue toggle              # all lights on/off
qs -c ionix ipc call hue set 40              # group brightness, percent
qs -c ionix ipc call hue light 3 true        # one light by bridge id
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
