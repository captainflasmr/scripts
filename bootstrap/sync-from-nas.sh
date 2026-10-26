#!/usr/bin/env bash
# sync-from-nas.sh - pull the up-to-date data set FROM the NAS onto THIS machine.
#
# The companion to refresh-usb.sh / install.sh: those seed a fresh box from a
# USB stick (a point-in-time snapshot). This refreshes a box that's already set
# up — e.g. a spare laptop you hop onto — with whatever is currently on the NAS,
# which holds the live mirror of your home under /volume1/Drive/Home.
#
#     ~/bin/bootstrap/sync-from-nas.sh            # mirror the ENTIRE home (default = --full)
#     ~/bin/bootstrap/sync-from-nas.sh --curated  # pull curated dotfiles only
#     ~/bin/bootstrap/sync-from-nas.sh --data     # also pull bulk data dirs
#     ~/bin/bootstrap/sync-from-nas.sh --no-mirror  # keep local-only files (additive)
#     ~/bin/bootstrap/sync-from-nas.sh --dry-run  # show what would change, do nothing
#
# --full (the default) is the exact pull-counterpart of do_backup: it uses the
# same shared lists (lib/home-include.txt + lib/home-exclude.txt, see
# lib/payload.sh) so whatever do_backup mirrors UP to the NAS, this brings back
# DOWN — a true round-trip. Pass --curated for the old default of curated
# dotfiles only (add --data for bulk).
#
# Reliability: it refuses to run unless the NAS is actually mounted and the
# Home/ mirror is visible, so a missing/half-up mount aborts the run rather than
# letting rsync sync from an empty path over your good local files. It mirrors
# by default (--delete: removes local-only files); pass --no-mirror for an
# additive pull that never deletes. Excluded machine-local data (VMs, containers,
# auth tokens, ...) is never deleted, and the only excluded local-only files a
# mirror does remove are disposable caches (Cache/, __pycache__, … , the
# JUNK_AT_RISK list below) — that is what lets a local-only tree like
# ~/.config/Cursor go instead of failing with rsync's "cannot delete non-empty
# directory" warnings. Full mode includes secrets (it is a whole-home mirror)
# and re-tightens their perms; in --curated mode they are never touched.
#
# Mozilla + opencode data (big, machine-local dirs) are always skipped on the
# pull — see SLOW_DIRS below. The push side (do_backup) still backs them up.
# Thunderbird's profile (~/.thunderbird) is skipped by default too — pass
# --thunderbird to pull it as well.
#
# Flags:
#   --curated    pull curated dotfiles only (default is full)
#   --no-home    skip curated dotfiles + bin + .config
#   --data       include bulk data dirs (default is dotfiles only)
#   --no-data    skip the bulk data dirs
#   --mirror     delete local-only files so the target exactly mirrors the NAS
#                (default)
#   --no-mirror  keep local-only files (additive pull; alias --additive)
#   --thunderbird  also pull ~/.thunderbird (skipped by default)
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
# NAS moved to the Atria mesh subnet (192.168.7.x) after leaving the Virgin router.
# Old Virgin-router IPs kept as fallbacks in case it gets plugged back in.
TARGET_IPS=("192.168.7.101" "192.168.0.10" "192.168.0.11" "192.168.7.103")

# --- args -----------------------------------------------------------------
DO_DATA=0; DO_HOME=1; FULL=1; MIRROR=1; DRYRUN=0; ASSUME_YES=0; DO_THUNDERBIRD=0
for a in "$@"; do
    case "$a" in
        --full)     FULL=1 ;;
        --curated)  FULL=0 ;;
        --no-home)  DO_HOME=0 ;;
        --data)     DO_DATA=1 ;;
        --no-data)  DO_DATA=0 ;;
        --mirror)   MIRROR=1 ;;
        --no-mirror|--additive) MIRROR=0 ;;
        --thunderbird|--with-thunderbird) DO_THUNDERBIRD=1 ;;
        --dry-run|-n) DRYRUN=1 ;;
        --yes|-y)   ASSUME_YES=1 ;;
        -h|--help)  sed -n '2,/^set /{/^set /d;p}' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)          die "unknown flag: $a (try --help)" ;;
    esac
done
export ASSUME_YES
[[ $FULL == 0 && $DO_DATA == 0 && $DO_HOME == 0 ]] && die "nothing to do: --no-data --no-home leaves nothing to sync"

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
        sudo mount -t nfs \
            -o nfsvers=3,rsize=1048576,wsize=1048576,noatime,actimeo=60 \
            "$ip:$REMOTE_PATH" "$NAS_MOUNT" &>/dev/null
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
RSYNC=( rsync -rlptv --human-readable )
(( MIRROR )) && RSYNC+=( --delete )
(( DRYRUN )) && RSYNC+=( -n )

# Pull-side skips: big, machine-local dirs that are slow to come down the wire
# and never need restoring wholesale. do_backup still mirrors them to the NAS.
# .thunderbird is the same kind of live mail profile and is skipped by default
# too — pass --thunderbird to pull it as well.
SLOW_DIRS=( .mozilla .config/mozilla .local/share/opencode )
(( DO_THUNDERBIRD )) || SLOW_DIRS+=( .thunderbird )
SLOW_EXCLUDES=()
for d in "${SLOW_DIRS[@]}"; do SLOW_EXCLUDES+=( --exclude "$d/" ); done

# Mirror mode deletes local-only files, but a plain exclude also *protects* what
# it matches from deletion. Local-only trees that hold nothing but excluded
# cache junk (e.g. ~/.config/Cursor, GIMP plug-in __pycache__) therefore linger
# with rsync's noisy "cannot delete non-empty directory: ..." warnings. Mark
# disposable patterns "at risk" (a receiver-side include: it cancels protection
# from deletion without un-hiding them on the sender, so caches are still never
# pulled FROM the NAS). Everything not listed here stays protected — VMs,
# containers, auth tokens, local state. Keep in step with the disposable
# patterns in lib/home-exclude.txt.
JUNK_AT_RISK=(
    'Cache' 'Cached*' 'Code Cache' 'Singleton*' '.cache*'
    'http-cache' 'image-dired' '.thumbnails'
    '__pycache__' '*.pyc' '*.o' '*.ali' 'node_modules'
    '*~' '.#*' '#*' '*.bak' '*.lock*' '*.socket' 'lock' '*[tT]rash*'
    '.claude/cache' '.claude/downloads' '.claude/file-history'
    '.claude/paste-cache' '.claude/session-env' '.claude/shell-snapshots'
    '.claude/statsig' '.claude/telemetry'
    '.config/Code/User/workspaceStorage' '.config/Code/logs'
    '.emacs.d/eln-cache' '.emacs.d/newsticker'
    '.local/share/RecentDocuments' '.local/share/baloo'
    '.local/share/gvfs-metadata' '.local/share/sddm/xorg-session.log'
    '.local/share/webkitgtk/databases'
    'qBittorrent/lockfile' 'qBittorrent/ipc-socket'
)
if (( MIRROR )); then
    for p in "${JUNK_AT_RISK[@]}"; do RSYNC+=( --filter "R $p" ); done
    unset p
fi

if (( FULL )); then
    SCOPE="FULL home (= do_backup set, incl. secrets)"
else
    SCOPE=""; (( DO_DATA )) && SCOPE+="data "; (( DO_HOME )) && SCOPE+="dotfiles"; SCOPE="${SCOPE% }"
fi
section "Sync FROM NAS"
info "source : $NAS_HOME/"
info "target : $HOME/"
info "scope  : $SCOPE"
info "mode   : $( ((MIRROR)) && echo 'mirror (delete local-only, default)' || echo 'additive (keep local-only)' )$( ((DRYRUN)) && echo '  [dry-run]' )"
(( DO_THUNDERBIRD )) || info "skip   : .thunderbird (machine-local; pass --thunderbird to pull)"
confirm "Pull data from the NAS onto this machine?" || die "aborted"

# --- full mirror (the exact pull-counterpart of do_backup) ----------------
# One rsync driven by the shared files-from/exclude-from, root = NAS Home, so
# anchored excludes (e.g. .config/Code/logs) match exactly as they do on push.
if [[ $FULL == 1 ]]; then
    section "Pulling FULL home (do_backup set)"
    info "files-from: $HOME_INCLUDE_FILE"
    start_epoch=$(date +%s)
    "${RSYNC[@]}" --files-from="$HOME_INCLUDE_FILE" --exclude-from="$HOME_EXCLUDE_FILE" \
        "${SLOW_EXCLUDES[@]}" "$NAS_HOME/" "$HOME/"
    elapsed=$(( $(date +%s) - start_epoch ))
    info "✓ full sync done (${elapsed}s)"
    # secrets came across in the mirror — re-tighten them (rsync preserves perms,
    # but a fresh box / different umask makes this a cheap belt-and-braces).
    if [[ $DRYRUN == 0 ]]; then
        [[ -d $HOME/.gnupg ]] && { find "$HOME/.gnupg" -type d -exec chmod 700 {} + ; find "$HOME/.gnupg" -type f -exec chmod 600 {} + ; }
        [[ -d $HOME/.ssh ]]   && { find "$HOME/.ssh"   -type d -exec chmod 700 {} + ; find "$HOME/.ssh"   -type f -exec chmod 600 {} + ; }
    fi
    section "Sync complete"
    (( DRYRUN )) && info "dry-run only — nothing was written. Drop --dry-run to apply."
    exit 0
fi

# --- bulk data ------------------------------------------------------------
if [[ $DO_DATA == 1 ]]; then
    section "Pulling bulk data"
    for d in "${DATA_DIRS[@]}"; do
        if [[ -d $NAS_HOME/$d ]]; then
            src_size=$(du -sh "$NAS_HOME/$d" 2>/dev/null | cut -f1)
            info "~/$d <- NAS ($src_size)"
            start_epoch=$(date +%s)
            "${RSYNC[@]}" "$NAS_HOME/$d/" "$HOME/$d/"
            elapsed=$(( $(date +%s) - start_epoch ))
            info "✓ ~/$d done (${elapsed}s)"
        else
            warn "skip (not on NAS): $d"
        fi
    done
fi

# --- curated home (dotfiles + bin + .config) ------------------------------
# Secrets are excluded on top of HOME_EXCLUDES — those belong in the gpg archive.
if [[ $DO_HOME == 1 ]]; then
    section "Pulling curated home"
    local_excludes=( "${HOME_EXCLUDES[@]}" "${SLOW_EXCLUDES[@]}"
        --exclude '.gnupg/' --exclude '.ssh/'
        --exclude '.authinfo' --exclude '.authinfo.gpg' --exclude '.mbsyncpass*' )
    home_start=$(date +%s)
    for item in "${HOME_INCLUDE[@]}"; do
        # skip whole items that are (or live under) a slow dir
        for d in "${SLOW_DIRS[@]}"; do
            if [[ $item == "$d" || $item == "$d"/* ]]; then
                warn "skip (slow dir): $item"; continue 2
            fi
        done
        if [[ -e $NAS_HOME/$item ]]; then
            info "~/$item <- NAS"
            "${RSYNC[@]}" "${local_excludes[@]}" "$NAS_HOME/$item" "$HOME/"
        else
            warn "skip (not on NAS): $item"
        fi
    done
    home_elapsed=$(( $(date +%s) - home_start ))
    info "✓ curated home done (${home_elapsed}s)"
fi

section "Sync complete"
(( DRYRUN )) && info "dry-run only — nothing was written. Drop --dry-run to apply."
exit 0
