#!/usr/bin/env bash
# sync-to-nas.sh - push locally-changed files UP to the NAS.
#
# The reverse companion to sync-from-nas.sh: that one refreshes THIS machine
# from the NAS; this one sends edits made HERE up to the NAS so the main laptop
# can pick them up. It never mirrors and never deletes: only paths journaled by
# nas-watch.sh (or given with --paths) are pushed, additively, and a file whose
# NAS copy is newer is left alone (rsync --update). Every transferred file is
# recorded in a per-machine manifest on the NAS, outside the Home/ mirror, in
# <nas>/.nas-sync/; the main laptop's nas-pending-pull.sh applies them at login.
#
#     sync-to-nas.sh                   # push changes queued by nas-watch.sh
#     sync-to-nas.sh --dry-run         # show what would transfer, write nothing
#     sync-to-nas.sh --paths bin .config/sway
#                                      # push specific paths (one-off/bootstrap)
#     sync-to-nas.sh --status          # show journal + manifests, change nothing
#     sync-to-nas.sh --if-mounted      # don't try to mount; push only if mounted
#     sync-to-nas.sh --quiet           # log only (used by the systemd timer)
#
# Deletions are deliberately not propagated. Machine-local live profiles
# (.mozilla, .thunderbird, .local/share/opencode, ...) are never pushed up —
# they stay the main laptop's to publish.
#
# State: ~/.local/state/nas-sync/ (journal, push.log)
# Manifest: <nas>/.nas-sync/pending-<host>.tsv

set -uo pipefail
BOOTSTRAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$BOOTSTRAP_DIR/lib/common.sh"
source "$BOOTSTRAP_DIR/lib/payload.sh"
source "$BOOTSTRAP_DIR/lib/nas.sh"
source "$BOOTSTRAP_DIR/lib/gitignore.sh"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/nas-sync"
JOURNAL="$STATE_DIR/dirty.list"
PUSH_LOG="$STATE_DIR/push.log"
NAS_SYNC_DIR="$NAS_MOUNT/.nas-sync"
HOST="$(hostname -s 2>/dev/null || echo unknown)"
HOST="${HOST//[^A-Za-z0-9._-]/_}"
MANIFEST="$NAS_SYNC_DIR/pending-$HOST.tsv"

# Live, machine-local application profiles: writes here are app state, not
# deliberate edits, so they are never pushed up. Same set sync-from-nas.sh
# refuses to pull; do_backup still publishes the main machine's copies.
REVERSE_SKIP=( .mozilla/ .config/mozilla/ .local/share/opencode/ .thunderbird/ )

DRYRUN=0 QUIET=0 IF_MOUNTED=0 WAIT=0 STATUS=0
PATHS=()
while (( $# )); do
    case "$1" in
        --pending) ;;                       # default mode; accepted for clarity
        --paths) ;;                         # marker; bare args collect below
        --dry-run|-n) DRYRUN=1 ;;
        --quiet|-q) QUIET=1 ;;
        --if-mounted|--no-mount) IF_MOUNTED=1 ;;
        --wait) WAIT="${2:-0}"; (( $# >= 2 )) && shift ;;
        --status) STATUS=1 ;;
        -h|--help) sed -n '2,/^set /{/^set /d;p}' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        --) shift; while (( $# )); do PATHS+=("$1"); shift; done; break ;;
        -*) die "unknown flag: $1 (try --help)" ;;
        *) PATHS+=("$1") ;;
    esac
    shift || break
done

say()     { (( QUIET )) || printf '%s\n' "$*"; }
logline() { printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$PUSH_LOG"; }
cap_log() {
    [[ -f $PUSH_LOG ]] || return 0
    (( $(wc -l < "$PUSH_LOG") > 2000 )) || return 0
    tail -n 500 "$PUSH_LOG" > "$PUSH_LOG.tmp" && mv "$PUSH_LOG.tmp" "$PUSH_LOG"
}

mkdir -p "$STATE_DIR"

# --- status (no NAS access required beyond an existing mount) --------------
if (( STATUS )); then
    echo "host      : $HOST"
    echo "state dir : $STATE_DIR"
    if [[ -f $JOURNAL ]]; then
        echo "journal   : $(wc -l < "$JOURNAL") queued path(s)"
        [[ -s $JOURNAL ]] && tail -n 5 "$JOURNAL" | sed 's/^/            /'
    else
        echo "journal   : (none)"
    fi
    if [[ -f $PUSH_LOG ]]; then
        echo "last push :"
        tail -n 4 "$PUSH_LOG" | sed 's/^/            /'
    fi
    if nas_mounted; then
        echo "manifest  : $MANIFEST"
        if [[ -f $MANIFEST ]]; then
            grep -v '^#' "$MANIFEST" | sed 's/^/            /'
            grep '^# pushed=' "$MANIFEST" | sed 's/^/            /'
        else
            echo "            (none)"
        fi
    else
        echo "NAS       : not mounted"
    fi
    exit 0
fi

# --- reach the NAS ---------------------------------------------------------
if (( IF_MOUNTED )); then
    if (( WAIT > 0 )); then
        if ! wait_for_nas "$WAIT"; then
            say "NAS not mounted at $NAS_MOUNT (waited ${WAIT}s) — nothing pushed."
            logline "skip: NAS not mounted"
            cap_log
            exit 0
        fi
    elif ! nas_mounted; then
        say "NAS not mounted at $NAS_MOUNT — nothing pushed."
        logline "skip: NAS not mounted"
        cap_log
        exit 0
    fi
else
    ensure_nas || die "NAS not mounted and could not be reached. Connect to your LAN
     (or run ~/bin/startup_root.sh) and re-run."
fi
[[ -n $(ls -A "$NAS_HOME" 2>/dev/null) ]] || die "$NAS_HOME is empty — refusing to push (mount looks wrong)."

# One push at a time (timer vs. manual vs. login) so the journal/manifest
# rotations below can't interleave.
if (( DRYRUN == 0 )); then
    exec 9>"$STATE_DIR/push.lock"
    flock -n 9 || { say "another push is already running"; exit 0; }
fi

# --- what to push ----------------------------------------------------------
PROCESSING=""
restore_journal() {
    [[ -n $PROCESSING && -f $PROCESSING ]] || return 0
    cat "$PROCESSING" >> "$JOURNAL"
    rm -f "$PROCESSING"
    PROCESSING=""
}
if (( ${#PATHS[@]} > 0 )); then
    RAW=$(mktemp)
    printf '%s\n' "${PATHS[@]}" > "$RAW"
else
    if [[ ! -s $JOURNAL ]]; then
        say "Nothing pending — no local changes queued."
        exit 0
    fi
    RAW=$(mktemp)
    if (( DRYRUN )); then
        sort -u "$JOURNAL" > "$RAW"
    else
        PROCESSING="$JOURNAL.processing.$$"
        mv "$JOURNAL" "$PROCESSING"        # watcher recreates $JOURNAL on its next event
        cp "$PROCESSING" "$RAW"
    fi
fi

# --- normalize the queued paths to $HOME-relative --------------------------
EXACT=$(mktemp)                 # the precise paths that changed / were asked for
while IFS= read -r p; do
    [[ -n $p ]] || continue
    p="${p#./}"
    if [[ $p == /* ]]; then
        [[ $p == "$HOME/"* ]] || { warn "skip (outside home): $p"; continue; }
        p="${p#"$HOME/"}"
    fi
    case "/$p/" in */../*) warn "skip (unsafe path): $p"; continue ;; esac
    [[ -e $HOME/$p ]] || continue          # deletions are not propagated
    printf '%s\n' "$p"
done < "$RAW" | sort -u > "$EXACT"
rm -f "$RAW"

if [[ ! -s $EXACT ]]; then
    say "Nothing to push (no existing files; deletions are not propagated)."
    restore_journal
    exit 0
fi

# --- filter rules -----------------------------------------------------------
build_gitignore_excludes "$HOME"

# Directory excludes match only the directory itself during traversal, so an
# explicitly-listed deep file below one would slip through (no traversal). Add
# a 'dir/***' companion for every exclude pattern: it matches the directory and
# everything under it, even as an exact file-list entry. Emitting each original
# immediately followed by its companion keeps rsync's first-match order, and
# the include overrides keep the same relative position as in do_backup so
# re-included trees still win over the git-ignore companions.
augment_excludes() {   # <file> -> stdout: originals + dir/*** companions
    local line
    while IFS= read -r line; do
        [[ -z $line || $line == \#* || $line == \;* ]] && continue
        printf '%s\n' "$line"
        case "$line" in
            *'/**'|*'***') ;;
            *) printf '%s/***\n' "${line%/}" ;;
        esac
    done < "$1"
}

AUG_EXCLUDE=$(mktemp)
augment_excludes "$HOME_EXCLUDE_FILE" > "$AUG_EXCLUDE"
AUG_GIT=""
if [[ -n $GIT_EXCLUDE_FILE ]]; then
    AUG_GIT=$(mktemp)
    augment_excludes "$GIT_EXCLUDE_FILE" > "$AUG_GIT"
fi
cleanup_filters() {
    cleanup_git_excludes
    rm -f "${AUG_EXCLUDE:-}" "${AUG_GIT:-}"
}
trap 'cleanup_filters' EXIT

RSYNC=( rsync -rlpt --update --human-readable )
RSYNC+=( --exclude-from="$AUG_EXCLUDE" )
for pat in "${REVERSE_SKIP[@]}"; do
    RSYNC+=( --exclude "$pat" --exclude "${pat%/}/***" )
done
RSYNC+=( --exclude '/nas/' --exclude '/nas/***'
         --exclude '/.local/state/nas-sync/' --exclude '/.local/state/nas-sync/***' )
# Overrides must precede the git-ignore excludes (rsync: first match wins).
for pat in "${GIT_INCLUDE_OVERRIDES[@]}"; do RSYNC+=( --include="$pat" ); done
[[ -n $AUG_GIT ]] && RSYNC+=( --exclude-from="$AUG_GIT" )

FINAL="$EXACT"

if [[ ! -s $FINAL ]]; then
    # Processed: excluded by the shared rules or already identical on the NAS.
    # Drop the journal — restoring it would re-scan the same paths forever.
    say "Nothing to push (every queued path is excluded or already identical)."
    rm -f "$FINAL" "$EXACT"
    rm -f "$PROCESSING"; PROCESSING=""
    exit 0
fi

# --- rsync up (additive; newer NAS copies win) ------------------------------
RUN=( "${RSYNC[@]}" --out-format='%i %n' )
(( DRYRUN )) && RUN+=( -n )
RUN+=( --files-from="$FINAL" "$HOME/" "$NAS_HOME/" )

say "Pushing $(wc -l < "$FINAL") queued path(s) to $NAS_HOME ..."
OUT=$(mktemp)
if (( QUIET )); then
    "${RUN[@]}" > "$OUT" 2>&1
    rc=$?
else
    "${RUN[@]}" | tee "$OUT"
    rc=${PIPESTATUS[0]}
fi

XFER=$(mktemp)
awk '/^>f/ { sub(/^>f[^ ]* /, ""); print }' "$OUT" > "$XFER"
n_xfer=$(wc -l < "$XFER")

# --- record what landed in the per-host manifest ---------------------------
if (( DRYRUN == 0 && n_xfer > 0 )); then
    mkdir -p "$NAS_SYNC_DIR"
    MAN_TMP=$(mktemp)
    while IFS= read -r f; do
        [[ -n $f && -f $HOME/$f ]] || continue
        size=$(stat -c %s -- "$HOME/$f" 2>/dev/null) || continue
        mtime=$(stat -c %Y -- "$HOME/$f" 2>/dev/null) || continue
        printf '%s\t%s\t%s\n' "$f" "$size" "$mtime"
    done < "$XFER" > "$MAN_TMP"
    MERGED=$(mktemp)
    {
        [[ -f $MANIFEST ]] && grep -v '^#' "$MANIFEST"
        cat "$MAN_TMP"
    } | awk -F'\t' 'NF>=3 && $1 !~ /^#/ {
                        if (!($1 in m) || $3+0 > m[$1]) { m[$1]=$3+0; s[$1]=$2 }
                    }
                    END { for (p in m) printf "%s\t%s\t%s\n", p, s[p], m[p] }' | sort > "$MERGED"
    {
        printf '# host=%s pushed=%s\n' "$HOST" "$(date -Is)"
        cat "$MERGED"
    } > "$MANIFEST.tmp.$$" && mv "$MANIFEST.tmp.$$" "$MANIFEST"
    rm -f "$MAN_TMP" "$MERGED"
fi

# --- journal bookkeeping ---------------------------------------------------
if (( DRYRUN )); then
    say "Dry run: $n_xfer file(s) would be pushed; nothing written."
    rm -f "$OUT" "$XFER" "$FINAL" "$EXACT"
    exit 0
fi
if (( rc != 0 )); then
    warn "rsync exited $rc — re-queuing paths for a retry."
    restore_journal
else
    rm -f "$PROCESSING"; PROCESSING=""
fi
rm -f "$OUT" "$XFER" "$FINAL" "$EXACT"
cap_log

if (( rc == 0 )); then
    logline "pushed $n_xfer changed file(s) to $NAS_HOME (host $HOST)"
    if (( n_xfer > 0 )); then
        say "Pushed $n_xfer file(s) — the main laptop will pull them at its next login."
    else
        say "No differences to push."
    fi
else
    logline "push FAILED (rc=$rc) after $n_xfer transferred file(s); paths re-queued"
    exit "$rc"
fi
