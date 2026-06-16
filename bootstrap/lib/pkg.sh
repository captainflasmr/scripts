#!/usr/bin/env bash
# pkg.sh - package-manager abstraction over pacman/yay (Arch) and apt (Mint),
# plus flatpak as the common GUI layer. Sourced after common.sh.
#
# Package list files (packages/*.txt) are plain newline lists. Blank lines and
# lines beginning with # are ignored, so you can comment a package out in place.

PKG_DIR="${PKG_DIR:-$BOOTSTRAP_DIR/packages}"

# apt invoked non-interactively: DEBIAN_FRONTEND=noninteractive stops debconf
# opening menus (e.g. the Postfix "mail server configuration" prompt that emacs
# drags in via its mail-transport-agent recommendation), and the dpkg conf
# options keep existing config files without asking on upgrades. Set as args so
# the env var survives sudo regardless of the sudoers env_keep policy.
APT=( sudo DEBIAN_FRONTEND=noninteractive apt-get
      -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold )

# read a package list file -> stdout, one package per line, comments stripped
_read_list() {
    local f="$PKG_DIR/$1"
    [[ -r $f ]] || { warn "package list '$1' not found, skipping"; return 0; }
    sed -E 's/#.*$//; s/[[:space:]]+$//' "$f" | grep -v '^[[:space:]]*$'
}

# --- AUR helper (Arch only) ----------------------------------------------
ensure_aur_helper() {
    command -v yay  &>/dev/null && { AUR_HELPER=yay;  return; }
    command -v paru &>/dev/null && { AUR_HELPER=paru; return; }
    info "Installing yay (AUR helper)…"
    sudo pacman -S --needed --noconfirm git base-devel || die "could not install build deps"
    local tmp; tmp=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin" || die "clone yay failed"
    ( cd "$tmp/yay-bin" && makepkg -si --noconfirm ) || die "building yay failed"
    rm -rf "$tmp"
    AUR_HELPER=yay
}

# --- system update --------------------------------------------------------
pkg_update() {
    section "System update"
    case "$DISTRO" in
        arch) sudo pacman -Syu --noconfirm ;;
        mint) "${APT[@]}" update && "${APT[@]}" -y upgrade ;;
        *)    warn "unknown distro, skipping system update" ;;
    esac
    if command -v flatpak &>/dev/null; then
        info "flatpak update"; flatpak update -y || true
    fi
}

# install one package if missing; $1 = package name
_native_install_one() {
    local p="$1"
    case "$DISTRO" in
        arch)
            if pacman -Qi "$p" &>/dev/null; then info "skip (installed): $p"; return; fi
            info "pacman: $p"; sudo pacman -S --needed --noconfirm "$p" \
                || warn "FAILED: $p" ;;
        mint)
            if dpkg -s "$p" &>/dev/null; then info "skip (installed): $p"; return; fi
            info "apt: $p"; "${APT[@]}" install -y "$p" || warn "FAILED: $p" ;;
    esac
}

# pkg_install_native <listfile>
pkg_install_native() {
    local list; list=$(_read_list "$1")
    [[ -z $list ]] && return 0
    while IFS= read -r p; do [[ -n $p ]] && _native_install_one "$p"; done <<< "$list"
}

# pkg_install_aur <listfile>  (Arch only; no-op elsewhere)
pkg_install_aur() {
    [[ $DISTRO == arch ]] || { warn "AUR list '$1' skipped (not Arch)"; return 0; }
    ensure_aur_helper
    local list; list=$(_read_list "$1")
    [[ -z $list ]] && return 0
    while IFS= read -r p; do
        [[ -z $p ]] && continue
        if pacman -Qi "$p" &>/dev/null; then info "skip (installed): $p"; continue; fi
        info "AUR: $p"; "$AUR_HELPER" -S --needed --noconfirm "$p" || warn "FAILED: $p"
    done <<< "$list"
}

# pkg_install_flatpak <listfile>
pkg_install_flatpak() {
    command -v flatpak &>/dev/null || { warn "flatpak not installed, skipping '$1'"; return 0; }
    # ensure flathub remote
    flatpak remote-list | grep -q flathub || \
        sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    local list; list=$(_read_list "$1")
    [[ -z $list ]] && return 0
    while IFS= read -r p; do
        [[ -z $p ]] && continue
        info "flatpak: $p"; flatpak install -y flathub "$p" || warn "FAILED: $p"
    done <<< "$list"
}

# pkg_remove <listfile>  (uninstall unwanted defaults)
pkg_remove() {
    local list; list=$(_read_list "$1")
    [[ -z $list ]] && return 0
    section "Removing unwanted packages"
    while IFS= read -r p; do
        [[ -z $p ]] && continue
        case "$DISTRO" in
            arch) pacman -Qi "$p" &>/dev/null && { info "remove: $p"; sudo pacman -Rns --noconfirm "$p" || warn "could not remove $p"; } ;;
            mint) dpkg -s "$p" &>/dev/null && { info "remove: $p"; "${APT[@]}" purge -y "$p" || warn "could not remove $p"; } ;;
        esac
    done <<< "$list"
}
