# Maintainer: Lucas <lucasion@hotmail.com>
#
# This PKGBUILD builds the shell from the working tree and is what the Ionix ISO
# ships. aur/build-aur.sh copies this directory into a scratch build dir first,
# so makepkg never writes into the git checkout, which is what makes $startdir
# safe to use here.
#
# It deliberately produces the *same package name and version scheme* as the AUR
# package (packaging/aur/PKGBUILD): the ISO ships `ionix-quickshell-git` at
# r<count>.<shorthash> of the submodule commit it was built from. Because the
# installed system drops the [ionix] repo after install, pacman then sees this as
# a foreign package, so `yay -Syu` picks up later AUR publishes normally.
#
# The two PKGBUILDs differ only in where the sources come from — keep
# depends/optdepends in sync between them.

pkgname=ionix-quickshell-git
_pkgname=ionix-quickshell
# Placeholder only; pkgver() below overwrites it on every build.
pkgver=r29.b2f4e2b
pkgrel=1
pkgdesc="Ionix Quickshell desktop shell — bar, popouts and OSD (git)"
arch=('any')
url="https://github.com/LucasionGS/ionix-quickshell"
license=('MIT')
depends=(
    'quickshell'
    'qt6-declarative'
    'qt6-svg'
    'qt6-wayland'
    'pipewire'
    'wireplumber'
    'networkmanager'
    'bluez'
    'bluez-utils'
    'upower'
    'polkit'
    # ionix-lock: flock for its single-instance guard.
    'util-linux'
    # ionix-calendar (the calendar sync daemon) and its meeting reminders.
    'python'
    'libnotify'
)
optdepends=(
    'swaync: notification centre integration for the bell module'
    'brightnessctl: backlight control and brightness OSD'
    'pavucontrol: advanced audio settings from the audio popout'
    'blueman: bluetooth manager GUI fallback'
    'nm-connection-editor: advanced network settings from the network popout'
    'hyprland: workspace, window and blur integration'
    'hyprlock: fallback when the Quickshell lock screen (ionix-lock) cannot lock'
    'qt6-multimedia-ffmpeg: video backgrounds on the lock screen'
    'fprintd: fingerprint unlock on the lock screen'
    'ioexplorer-git: application launcher target for the logo button'
    'toxen-mini: Toxen music player integration'
    'ttf-jetbrains-mono-nerd: the glyph font the bar is designed around'
    'libsecret: keep the calendar sign-in token in the keyring instead of a file'
    'gnome-keyring: a Secret Service for libsecret to store that token in'
    'wl-clipboard: copy the calendar sign-in code from the popout'
    'xdg-utils: open meeting links and the sign-in page in your browser'
)
provides=("$_pkgname")
conflicts=("$_pkgname")
source=()

# Must match aur-publish.sh's formula exactly, or an ISO build and an AUR publish
# of the same commit would disagree about which one is newer.
#
# build-aur.sh strips .git from the scratch copy (makepkg must not write inside a
# checkout, and the submodule's .git is a gitlink file anyway), so it writes the
# version to .pkgver beforehand. The git branch below is the fallback for running
# makepkg by hand inside a real checkout.
pkgver() {
    if [[ -f "$startdir/.pkgver" ]]; then
        cat "$startdir/.pkgver"
    elif git -C "$startdir" rev-parse HEAD >/dev/null 2>&1; then
        printf "r%s.%s" \
            "$(git -C "$startdir" rev-list --count HEAD)" \
            "$(git -C "$startdir" rev-parse --short HEAD)"
    else
        printf '%s' "$pkgver"
    fi
}

package() {
    make -C "$startdir" DESTDIR="$pkgdir" PREFIX=/usr PKGNAME="$pkgname" install
}
