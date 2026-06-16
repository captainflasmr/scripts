#!/usr/bin/env bash
# install.sh - one-command setup for a freshly-installed Arch or Linux Mint box.
#
# Run it straight off the inserted USB stick:
#     cd /run/media/$USER/<STICK>      # wherever it mounted
#     ./install.sh
#
# It detects the distro, installs packages, restores your home/secrets/data
# from the stick, and applies a few system tweaks. Everything is idempotent,
# so re-running is safe. Nothing here depends on the NAS or the network being
# reachable (except package downloads).
#
# Flags:
#   --yes            assume "yes" to confirmation prompts
#   --no-data        skip restoring bulk data (DCIM/source/wallpaper)
#   --no-secrets     skip restoring .ssh/.gnupg/.authinfo
#   --no-packages    skip all package installation
#   --packages-only  only install packages, nothing else
#   --remove         also remove the unwanted-defaults list (arch-remove.txt)
#   --step <name>    run a single step function and exit (for testing)
#   -h, --help       this help

set -uo pipefail

# resolve our own location -> payload root is alongside this script
BOOTSTRAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$BOOTSTRAP_DIR"          # home/, data/, secrets live next to install.sh on the stick

source "$BOOTSTRAP_DIR/lib/common.sh"
source "$BOOTSTRAP_DIR/lib/pkg.sh"
source "$BOOTSTRAP_DIR/lib/steps.sh"

# --- args -----------------------------------------------------------------
ASSUME_YES=0; DO_DATA=1; DO_SECRETS=1; DO_PACKAGES=1; PACKAGES_ONLY=0; DO_REMOVE=0; RUN_STEP=
while [[ $# -gt 0 ]]; do
    case "$1" in
        --yes|-y)       ASSUME_YES=1 ;;
        --no-data)      DO_DATA=0 ;;
        --no-secrets)   DO_SECRETS=0 ;;
        --no-packages)  DO_PACKAGES=0 ;;
        --packages-only) PACKAGES_ONLY=1 ;;
        --remove)       DO_REMOVE=1 ;;
        --step)         [[ -n ${2:-} ]] || die "--step requires a function name"; RUN_STEP=$2; shift ;;
        -h|--help)      sed -n '2,/^set /{/^set /d;p}' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)              die "unknown flag: $1 (try --help)" ;;
    esac
    shift
done
export ASSUME_YES

if [[ -n $RUN_STEP ]]; then
    detect_distro
    sudo_keepalive
    declare -f "$RUN_STEP" &>/dev/null || die "unknown step: $RUN_STEP"
    "$RUN_STEP"
    exit $?
fi

# --- preflight ------------------------------------------------------------
[[ $EUID -eq 0 ]] && die "Run as your normal user, not root (the script uses sudo where needed)."
detect_distro
section "Bootstrap install"
info "user:    $USER"
info "distro:  $DISTRO"
info "payload: $SRC_DIR"
[[ $DISTRO == unknown ]] && die "Unsupported distro. This targets Arch- and Debian/Mint-family systems."
require_cmd rsync "Install rsync first (it's in the package lists, but needed up front)."
confirm "Proceed with install on this machine?" || die "aborted"
sudo_keepalive

# --- packages -------------------------------------------------------------
if [[ $DO_PACKAGES == 1 ]]; then
    pkg_update
    [[ $DO_REMOVE == 1 && $DISTRO == arch ]] && pkg_remove arch-remove.txt
    section "Installing native packages"
    case "$DISTRO" in
        arch) pkg_install_native arch-pacman.txt
              pkg_install_aur    arch-aur.txt ;;
        mint) pkg_install_native mint-apt.txt ;;
    esac
    section "Installing flatpaks"
    pkg_install_flatpak flatpak.txt
fi

if [[ $PACKAGES_ONLY == 1 ]]; then step_done; exit 0; fi

# --- restore + system tweaks ----------------------------------------------
step_disable_display_manager   # self-skips on Mint; only disables the DM on Arch
step_restore_home
[[ $DO_SECRETS == 1 ]] && step_restore_secrets
[[ $DO_DATA    == 1 ]] && step_restore_data
step_set_shell
step_groups
if confirm "Set up reboot NAS auto-mount cron (only useful on your LAN)?"; then
    step_cron_nasmount
fi
step_quirk_samsung_backlight
step_mint_keymap
step_mu_init
step_done
