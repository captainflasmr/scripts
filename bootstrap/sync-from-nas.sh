#!/usr/bin/env bash
# sync-from-nas.sh - pull the up-to-date data set FROM the NAS onto THIS machine.
#
# The companion to refresh-usb.sh / install.sh: those seed a fresh box from a
# USB stick (a point-in-time snapshot). This refreshes a box that's already set
# up — e.g. a spare laptop you hop onto — with whatever is currently on the NAS,
# which holds the live mirror of your home under /volume1/Drive/Home.
#
#     ~/bin/bootstrap/sync-from-nas.sh            # pull bulk data (DCIM/source/…)
#     ~/bin/bootstrap/sync-from-nas.sh --home     # also refresh dotfiles/.config
#     ~/bin/bootstrap/sync-from-nas.sh --dry-run  # show what would change, do nothing
#
# Reliability: it refuses to run unless the NAS is actually mounted and the
# Home/ mirror is visible, so a missing/half-up mount aborts the run rather than
# letting rsync sync from an empty path over your good local files. It pulls
# additively by default (never deletes local-only files) — pass --mirror for an
# exact mirror of the NAS. Secrets (.ssh/.gnupg/.authinfo) are never touched.
#
# Flags:
#   --home       also pull curated dotfiles + bin + .config (HOME_INCLUDE)
#   --no-data    skip the bulk data dirs (use with --home for dotfiles only)
#   --mirror     delete local-only files so the target exactly mirrors the NAS
#   --dry-run    rsync -n: report changes without writing anything
#   --yes, -y    assume "yes" to the confirmation prompt
#   -h, --help   this help

set -uo pipefail
BOOTSTRAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$BOOTSTRAP_DIR/lib/common.sh"
source "$BOOTSTRAP_DIR/lib/payload.sh"   # DATA_DIRS / HOME_INCLUDE / HOME_EXCLUDES

# --- NAS connection (mirror of ~/bin/startup_root.sh) ---------------------
NAS_MOUNT="$HOME/nas"
NAS_HOME="$NAS_MOUNT/Home"               # the live mirror of $HOME on the NAS
REMOTE_PATH="/volume1/Drive"
TARGET_IPS=("192.168.0.10" "192.168.0.11" "192.168.7.103")

# --- args -----------------------------------------------------------------
DO_DATA=1; DO_HOME=0; MIRROR=0; DRYRUN=0; ASSUME_YES=0
for a in "$@"; do
    case "$a" in
        --home)     DO_HOME=1 ;;
        --no-data)  DO_DATA=0 ;;
        --mirror)   MIRROR=1 ;;
        --dry-run|-n) DRYRUN=1 ;;
        --yes|-y)   ASSUME_YES=1 ;;
        -h|--help)  sed -n '2,/^set /{/^set /d;p}' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)          die "unknown flag: $a (try --help)" ;;
    esac
done
export ASSUME_YES
[[ $DO_DATA == 0 && $DO_HOME == 0 ]] && die "nothing to do: --no-data without --home"

require_cmd rsync "Install rsync first."

# --- ensure the NAS is mounted (best-effort, then a hard guard) -----------
# If the Home/ mirror isn't visible, try a single mount across the known IPs.
# 'mountpoint' confirms it's a real NFS mount, not a stale empty ~/nas dir.
ensure_nas() {
    if mountpoint -q "$NAS_MOUNT" && [[ -d $NAS_HOME ]]; then
        info "NAS already mounted at $NAS_MOUNT"; return 0
    fi
    section "Mounting NAS"
    mkdir -p "$NAS_MOUNT"
    local ip
    for ip in "${TARGET_IPS[@]}"; do
        ping -c1 -W1 "$ip" &>/dev/null || continue
        info "trying $ip:$REMOTE_PATH"
        sudo mount -t nfs -o nfsvers=3 "$ip:$REMOTE_PATH" "$NAS_MOUNT" &>/dev/null
        mountpoint -q "$NAS_MOUNT" && [[ -d $NAS_HOME ]] && { info "mounted via $ip"; return 0; }
    done
    return 1
}

if ! ensure_nas; then
    die "NAS not mounted and could not be reached. Connect to your LAN (or run
     ~/bin/startup_root.sh) so $NAS_HOME is available, then re-run."
fi
# Belt-and-braces: never sync from an empty source.
[[ -n $(ls -A "$NAS_HOME" 2>/dev/null) ]] || die "$NAS_HOME is empty — refusing to sync (mount looks wrong)."

# --- assemble rsync flags -------------------------------------------------
RSYNC=( rsync -rlptP --human-readable )
(( MIRROR )) && RSYNC+=( --delete )
(( DRYRUN )) && RSYNC+=( -n )

section "Sync FROM NAS"
info "source : $NAS_HOME/"
info "target : $HOME/"
info "mode   : $( ((MIRROR)) && echo 'mirror (--delete local-only)' || echo 'additive' )$( ((DRYRUN)) && echo '  [dry-run]' )"
confirm "Pull data from the NAS onto this machine?" || die "aborted"

# --- bulk data ------------------------------------------------------------
if [[ $DO_DATA == 1 ]]; then
    section "Pulling bulk data"
    for d in "${DATA_DIRS[@]}"; do
        if [[ -d $NAS_HOME/$d ]]; then
            info "~/$d <- NAS ($(du -sh "$NAS_HOME/$d" 2>/dev/null | cut -f1))"
            "${RSYNC[@]}" "$NAS_HOME/$d/" "$HOME/$d/"
        else
            warn "skip (not on NAS): $d"
        fi
    done
fi

# --- curated home (dotfiles + bin + .config) ------------------------------
# Secrets are excluded on top of HOME_EXCLUDES — those belong in the gpg archive.
if [[ $DO_HOME == 1 ]]; then
    section "Pulling curated home"
    local_excludes=( "${HOME_EXCLUDES[@]}"
        --exclude '.gnupg/' --exclude '.ssh/'
        --exclude '.authinfo' --exclude '.authinfo.gpg' --exclude '.mbsyncpass*' )
    for item in "${HOME_INCLUDE[@]}"; do
        if [[ -e $NAS_HOME/$item ]]; then
            info "~/$item <- NAS"
            "${RSYNC[@]}" "${local_excludes[@]}" "$NAS_HOME/$item" "$HOME/"
        else
            warn "skip (not on NAS): $item"
        fi
    done
fi

section "Sync complete"
(( DRYRUN )) && info "dry-run only — nothing was written. Drop --dry-run to apply."
exit 0
