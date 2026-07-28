# Maintainer: Lucas <lucasion@hotmail.com>
#
# This PKGBUILD builds the shell from the working tree and is what the Ionix ISO
# ships. aur/build-aur.sh copies this directory into a scratch build dir first,
# so makepkg never writes into the git checkout, which is what makes $startdir
# safe to use here.
#
# End users get ionix-quickshell-git from the AUR instead (packaging/aur/PKGBUILD).
# The two mutually provide/conflict on this name, so switching is a single
# transaction in either direction.

pkgname=ionix-quickshell
pkgver=0.1.0
pkgrel=1
pkgdesc="Ionix Quickshell desktop shell — bar, popouts and OSD"
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
)
optdepends=(
    'swaync: notification centre integration for the bell module'
    'brightnessctl: backlight control and brightness OSD'
    'pavucontrol: advanced audio settings from the audio popout'
    'blueman: bluetooth manager GUI fallback'
    'nm-connection-editor: advanced network settings from the network popout'
    'hyprland: workspace, window and blur integration'
    'hyprlock: lock action in the power menu'
    'ioexplorer-git: application launcher target for the logo button'
    'toxen-mini: Toxen music player integration'
    'ttf-jetbrains-mono-nerd: the glyph font the bar is designed around'
)
provides=('ionix-quickshell')
conflicts=('ionix-quickshell-git')
source=()

package() {
    make -C "$startdir" DESTDIR="$pkgdir" PREFIX=/usr PKGNAME="$pkgname" install
}
