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
- **Calendar** — the popout has a real calendar behind it: dots on busy days, a per-day agenda,
  and an editor to add, change and delete your own events (all-day or timed, with a location, a
  meeting link that becomes a **Join** button, and daily/weekly/monthly/yearly repeats). The next
  meeting shows in the clock pill and a notification reminds you before each one. Your events
  live in a JSON file under `~/.local/share`. Optionally sign in to **Outlook / Microsoft 365**
  and your work meetings (Teams links included) join the same list — the daemon is written so
  other services slot in later.
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

### Calendar

On by default as a **local** calendar. The shell runs `ionix-calendar`, a small stdlib-only
Python daemon, which keeps your events in `$XDG_DATA_HOME/ionix/calendar/local.json` and
expands them (repeats included) into `$XDG_STATE_HOME/ionix/quickshell/calendar/events.json`,
which the popout and clock read. Add an event with the **+** beside the day's agenda, click an
event to edit or delete it; while adding, clicking another day in the grid moves the event
there. From a terminal or a keybind:

```bash
ionix-calendar add "Dentist" "2026-09-10 14:00" 45   # 45-minute event
ionix-calendar add "Trip" "2026-09-12"               # all-day
ionix-calendar list                                  # upcoming, with ids
ionix-calendar remove <id>
qs -c ionix ipc call calendar newEvent               # open the popout on the editor
```

The settings page's **Calendar** row is *Off / Local / Outlook*. Off stops the daemon and takes
the calendar out of the popout entirely.

#### Outlook / Microsoft 365

Pick *Outlook* and your work calendar is layered on top of the local one — same list, same
dots, Teams meetings with a **Join** button, reminders for both. A provider is a Python class
plus one entry in the settings picker; the QML never learns which service is behind an event.

Microsoft needs an app registration to let anything sign in, and that is the one thing you have
to do by hand:

1. In [Entra admin center](https://entra.microsoft.com) go to *Identity → Applications →
   App registrations → New registration*. Any name; *Accounts in this organizational directory
   only*; no redirect URI.
2. On the app's *Authentication* page set **Allow public client flows** to *Yes* (the sign-in
   is the device-code flow).
3. Under *API permissions* add *Microsoft Graph → Delegated → `Calendars.Read`*.
4. Copy the *Application (client) ID* into `config.json`:

```jsonc
{
  "calendar": {
    "provider": "outlook",
    "outlook": {
      "clientId": "00000000-0000-0000-0000-000000000000",
      "tenant": "organizations"      // or your tenant id; "consumers" for outlook.com; "common" for both
    },
    "calendars": [],                 // include-list of calendar names or ids; [] = all
    "showNext": true,                // next meeting in the clock pill, within upcomingWindow minutes
    "upcomingWindow": 60,
    "reminders": true,               // notification reminderMinutes before each meeting, with Join
    "reminderMinutes": 5
  }
}
```

Then open the calendar, click **Sign in to Outlook**, enter the code it shows at
`microsoft.com/devicelogin`, and the work meetings appear beside your own. The token goes into your keyring via
`secret-tool` when a Secret Service is running, otherwise into a `0600` file next to the
cache. Sign out from the popout's footer. If your tenant does not let users register apps, ask
an admin to register one for you — the registration is the only thing that touches the tenant;
the sign-in is your own account with your own consent. In most tenants `Calendars.Read` also
needs an admin to grant consent once on that registration (*API permissions → Grant admin
consent*); Microsoft's "Need admin approval" page at sign-in is how you find out. Teams meetings are ordinary Outlook
events with a join link, so nothing Teams-specific is needed.

The daemon is usable on its own too:

```bash
ionix-calendar login        # sign in from a terminal instead of the popout
ionix-calendar calendars    # list the account's calendars for the include-list
ionix-calendar sync         # one-shot sync
ionix-calendar status       # what the popout sees
qs -c ionix ipc call calendar next    # "in 12m 10:00 Standup"
qs -c ionix ipc call calendar join    # open the next meeting's link
```


### Lock screen

`ionix-lock` locks the session with `lock.qml`, the second entry point in this tree. It runs as a
**separate Quickshell process**, so a bar crash or hot-reload can never take the lock with it, but it
reads the same merged config, so it wears the active theme and restyles live while locked.

- **Background:** by default, whatever awww is showing on each monitor. `lock.background.image` can
  name a picture or a **directory**, which becomes a slideshow. `lock.background.video` is looped
  and muted (needs `qt6-multimedia-ffmpeg`, and is skipped on battery unless `videoOnBattery`). Either
  key may be a per-monitor map:
  ```json
  { "lock": { "background": { "video": { "DP-1": "~/Videos/rain.mp4", "*": "" },
                              "image": "~/Pictures/Wallpapers" } } }
  ```
- **Screensaver:** after `lock.screensaver.after` idle seconds the card fades out, the blur clears,
  stills slowly pan and zoom, and the clock moves to the middle and wanders once a minute. Any key or
  mouse movement brings the card back, and the key you pressed still counts as typed.
- **Unlock:** password through PAM, raced against fprintd when a reader is present — the same
  "either works, never blocks the other" behaviour hyprlock has. Media controls, battery and
  suspend/restart/shut down (the last two need a second click) are available while locked.
- **Failure handling:** `ionix-lock` waits for the compositor to confirm every output is covered.
  If that doesn't happen within 8 s, or the lock screen dies while locked, it hands the session to
  **hyprlock** instead. A second `ionix-lock` while locked is a no-op.

The PAM stacks live in `ionix/lock/pam/` and are read in place through `PamContext.configDirectory`.
The password stack is `pam_unix` alone, **not** `include login`, because that stack's `pam_faillock`
locks you out of your own desktop for ten minutes after three typos.

Hyprland needs `misc.allow_session_lock_restore = true` for the hyprlock takeover to work.

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

# the lock screen is its own instance, addressed by path
qs -p /etc/xdg/quickshell/ionix/lock.qml ipc call lock status
qs -p /etc/xdg/quickshell/ionix/lock.qml ipc call lock sleep   # straight to the screensaver
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

# the lock screen: run it inside a nested Hyprland, never your own session,
# unless you are sure you can type your password into it
Hyprland -c /some/minimal.conf &            # opens as a window; note its wayland-N
WAYLAND_DISPLAY=wayland-2 IONIX_LOCK_DEV=1 qs -p "$PWD/ionix/lock.qml"
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
