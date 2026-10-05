#!/usr/bin/env bash
# nas-watch.sh - journal home-file writes so sync-to-nas.sh can push them.
#
# Runs as a systemd user service (nas-watch.service). It watches the directories
# in the shared include list (lib/home-include.txt) with inotify and appends
# every changed path to ~/.local/state/nas-sync/dirty.list. It does no syncing
# itself; nas-push.timer drains the journal every few minutes via
# sync-to-nas.sh. Paths that the push would exclude anyway are harmless here:
# rsync filters them at push time, and the journal is only a discovery aid.
#
# Machine-local paths (the state dir itself, ~/nas) are skipped so the journal
# never feeds on its own bookkeeping or the NAS mount.

set -uo pipefail
BOOTSTRAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$BOOTSTRAP_DIR/lib/common.sh"
source "$BOOTSTRAP_DIR/lib/payload.sh"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/nas-sync"
JOURNAL="$STATE_DIR/dirty.list"
mkdir -p "$STATE_DIR"
touch "$JOURNAL"

require_cmd inotifywait "Install inotify-tools first."

# Watch every existing directory from the include list, dropping any path that
# is nested under one already selected (inotify's -r covers it).
WATCH=()
for item in "${HOME_FULL[@]}"; do
    [[ $item == /* || $item == *..* ]] && continue
    [[ -d $HOME/$item ]] || continue
    nested=0
    for w in "${WATCH[@]}"; do
        [[ $item == "$w"/* ]] && { nested=1; break; }
    done
    (( nested )) && continue
    WATCH+=( "$HOME/$item" )
done
(( ${#WATCH[@]} )) || die "no watch roots exist (is $HOME empty?)"

info "nas-watch: watching ${#WATCH[@]} root(s); journal: $JOURNAL"

events=0
# inotifywait exiting (error, watch limit, ...) makes the pipeline exit
# non-zero via pipefail, so systemd restarts the service (Restart=on-failure).
inotifywait -m -r -q --format '%w%f' \
    -e close_write -e create -e moved_to \
    "${WATCH[@]}" |
while IFS= read -r abs; do
    rel=${abs#"$HOME/"}
    [[ -z $rel || $rel == "$abs" ]] && continue
    case "$rel" in
        .local/state/nas-sync|.local/state/nas-sync/*) continue ;;
        nas|nas/*) continue ;;
        # Live machine-local profiles: noisy and never pushed (see the
        # REVERSE_SKIP list in sync-to-nas.sh) — don't even journal them.
        .mozilla|.mozilla/*) continue ;;
        .config/mozilla|.config/mozilla/*) continue ;;
        .local/share/opencode|.local/share/opencode/*) continue ;;
        .thunderbird|.thunderbird/*) continue ;;
        .config/chromium|.config/chromium/*) continue ;;
    esac
    printf '%s\n' "$rel" >> "$JOURNAL"
    events=$(( events + 1 ))
    if (( events >= 500 )); then
        # Compact in place so an off-LAN laptop doesn't grow a huge journal.
        sort -u "$JOURNAL" > "$JOURNAL.tmp" && mv "$JOURNAL.tmp" "$JOURNAL"
        events=0
    fi
done
exit "${PIPESTATUS[0]}"
