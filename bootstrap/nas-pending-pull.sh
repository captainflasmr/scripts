#!/usr/bin/env bash
# nas-pending-pull.sh - apply changes pushed up from other machines via the NAS.
#
# The pull half of the two-way flow: sync-to-nas.sh (on the machine you edit)
# records transferred files in per-host manifests under <nas>/.nas-sync/; this
# script reads those manifests and pulls exactly those files down. It never
# mirrors, never deletes, and never overwrites a local file that is newer than
# the NAS copy (rsync --update) — those are reported as conflicts instead. Run
# it before do_backup pushes the home up; do_backup does that automatically.
#
#     nas-pending-pull.sh                # pull pending changes, print a report
#     nas-pending-pull.sh --terminal     # ... and show the report in a terminal
#     nas-pending-pull.sh --auto         # --terminal + --if-mounted --wait 90
#     nas-pending-pull.sh --quiet        # log only (used by do_backup)
#     nas-pending-pull.sh --dry-run      # report what would happen, write nothing
#     nas-pending-pull.sh --include-self # also process manifests from this host
#
# Report + state: ~/.local/state/nas-sync/last-pull.log. Applied manifests are
# archived under <nas>/.nas-sync/done/ (with any conflicts alongside).

set -uo pipefail
BOOTSTRAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$BOOTSTRAP_DIR/lib/common.sh"
source "$BOOTSTRAP_DIR/lib/nas.sh"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/nas-sync"
LOG="$STATE_DIR/last-pull.log"
NAS_SYNC_DIR="$NAS_MOUNT/.nas-sync"
HOST="$(hostname -s 2>/dev/null || echo unknown)"
HOST="${HOST//[^A-Za-z0-9._-]/_}"

DRYRUN=0 QUIET=0 TERMINAL=0 IF_MOUNTED=0 WAIT=0 INCLUDE_SELF=0
while (( $# )); do
    case "$1" in
        --terminal) TERMINAL=1 ;;
        --auto) TERMINAL=1; IF_MOUNTED=1; (( WAIT == 0 )) && WAIT=90 ;;
        --quiet|-q) QUIET=1 ;;
        --if-mounted|--no-mount) IF_MOUNTED=1 ;;
        --wait) WAIT="${2:-0}"; (( $# >= 2 )) && shift ;;
        --include-self) INCLUDE_SELF=1 ;;
        --dry-run|-n) DRYRUN=1 ;;
        --yes|-y) : ;;                     # never prompts; accepted for symmetry
        -h|--help) sed -n '2,/^set /{/^set /d;p}' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) die "unknown flag: $1 (try --help)" ;;
    esac
    shift || break
done

mkdir -p "$STATE_DIR"

hsize() { numfmt --to=iec --suffix=B -- "${1:-0}" 2>/dev/null || printf '%sB' "${1:-0}"; }

open_report_terminal() {
    local log="$1"
    local cmd='cat "$1"; printf "\n-- press any key to close --"; IFS= read -rsn1; echo'
    if command -v foot >/dev/null 2>&1; then
        foot -a nas-sync-report -T "NAS sync report" sh -c "$cmd" _ "$log" &
    elif command -v kitty >/dev/null 2>&1; then
        kitty --title "NAS sync report" sh -c "$cmd" _ "$log" &
    elif command -v alacritty >/dev/null 2>&1; then
        alacritty -t "NAS sync report" -e sh -c "$cmd" _ "$log" &
    fi
}

# --- reach the NAS (never sudo-mounts when --if-mounted) -------------------
if (( IF_MOUNTED )); then
    if (( WAIT > 0 )); then
        if ! wait_for_nas "$WAIT"; then
            printf '%s NAS not mounted after %ss; no pending pull.\n' "$(date '+%F %T')" "$WAIT" > "$LOG"
            (( QUIET )) || cat "$LOG"
            exit 0
        fi
    elif ! nas_mounted; then
        printf '%s NAS not mounted; no pending pull.\n' "$(date '+%F %T')" > "$LOG"
        (( QUIET )) || cat "$LOG"
        exit 0
    fi
else
    ensure_nas || die "NAS not mounted and could not be reached."
fi
[[ -n $(ls -A "$NAS_HOME" 2>/dev/null) ]] || die "$NAS_HOME is empty — refusing to pull (mount looks wrong)."

exec 9>"$STATE_DIR/pull.lock"
flock -n 9 || exit 0                       # another pull is already running

# --- collect foreign-host manifests ---------------------------------------
shopt -s nullglob
manifests=( "$NAS_SYNC_DIR"/pending-*.tsv )
shopt -u nullglob
todo=()
for m in "${manifests[@]}"; do
    h=$(basename "$m" .tsv); h=${h#pending-}
    [[ $h == "$HOST" && $INCLUDE_SELF == 0 ]] && continue
    todo+=( "$m" )
done
if (( ${#todo[@]} == 0 )); then
    printf '%s No pending changes on the NAS.\n' "$(date '+%F %T')" > "$LOG"
    (( QUIET )) || cat "$LOG"
    exit 0
fi

REPORT="$LOG.tmp.$$"
{
    printf 'NAS pending pull — %s\n' "$(date '+%F %T')"
    printf 'host: %s%s\n' "$HOST" "$( ((DRYRUN)) && echo '  [dry-run]' )"
    printf -- '------------------------------------------------------------------------\n'
} > "$REPORT"

total_pulled=0; total_conf=0; total_failed=0; total_same=0

for m in "${todo[@]}"; do
    h=$(basename "$m" .tsv); h=${h#pending-}
    pushed=$(sed -n 's/^# pushed=//p' "$m" | head -1)
    printf '\n-- from %s%s\n' "$h" "${pushed:+ (pushed $pushed)}" >> "$REPORT"

    declare -A MT=() SZ=()
    new=(); upd=(); conf=(); same=(); bad=()
    while IFS=$'\t' read -r p size mtime; do
        [[ -n $p && $p != \#* ]] || continue
        if [[ $p == /* ]]; then bad+=( "$p" ); continue; fi
        case "/$p/" in */../*) bad+=( "$p" ); continue ;; esac
        if [[ -z $mtime || ! $mtime =~ ^[0-9]+$ ]]; then bad+=( "$p" ); continue; fi
        MT[$p]=$mtime; SZ[$p]=${size:-0}
        if [[ ! -e $HOME/$p ]]; then
            new+=( "$p" )
        elif [[ ! -f $HOME/$p ]]; then
            bad+=( "$p" )                  # dir/symlink in the way
        else
            lm=$(stat -c %Y -- "$HOME/$p")
            if (( mtime > lm + 1 )); then upd+=( "$p" )
            elif (( lm > mtime + 1 )); then conf+=( "$p" )
            else same+=( "$p" )
            fi
        fi
    done < <(grep -v '^#' "$m" 2>/dev/null)

    for p in "${bad[@]}"; do
        printf '   ignored  : %s (unsupported path)\n' "$p" >> "$REPORT"
    done
    for p in "${conf[@]}"; do
        printf '   conflict : %s (%s) — local copy is newer; kept it\n' \
               "$p" "$(hsize "${SZ[$p]:-0}")" >> "$REPORT"
    done
    (( ${#same[@]} > 0 )) && printf '   same     : %d file(s) unchanged\n' "${#same[@]}" >> "$REPORT"

    # --- pull this manifest -------------------------------------------------
    pulled=(); failed=()
    pull=( "${new[@]}" "${upd[@]}" )
    if (( ${#pull[@]} > 0 )); then
        list=$(mktemp)
        printf '%s\n' "${pull[@]}" > "$list"
        rsync_args=( -rlpt --update --files-from="$list" )
        (( DRYRUN )) && rsync_args+=( -n )
        rsync "${rsync_args[@]}" "$NAS_HOME/" "$HOME/" || true
        rm -f "$list"
        if (( DRYRUN )); then
            pulled=( "${pull[@]}" )
        else
            for p in "${pull[@]}"; do
                if [[ -f $HOME/$p ]] && (( $(stat -c %Y -- "$HOME/$p") >= MT[$p] - 1 )); then
                    pulled+=( "$p" )
                else
                    failed+=( "$p" )
                fi
            done
        fi
    fi
    for p in "${new[@]}"; do
        printf '   new      : %s (%s)\n' "$p" "$(hsize "${SZ[$p]:-0}")" >> "$REPORT"
    done
    for p in "${upd[@]}"; do
        printf '   update   : %s (%s)\n' "$p" "$(hsize "${SZ[$p]:-0}")" >> "$REPORT"
    done
    for p in "${failed[@]}"; do
        printf '   FAILED   : %s — not applied, will retry at the next pull\n' "$p" >> "$REPORT"
    done

    # --- archive (or keep failed entries for a retry) ------------------------
    if (( DRYRUN == 0 )); then
        done_dir="$NAS_SYNC_DIR/done"; mkdir -p "$done_dir"
        stamp=$(date +%Y%m%d-%H%M%S)
        if (( ${#failed[@]} == 0 )); then
            mv "$m" "$done_dir/${h}-${stamp}.tsv"
        else
            printf '# host=%s pushed=%s\n' "$h" "$(date -Is)" > "$m.tmp.$$"
            for p in "${failed[@]}"; do
                printf '%s\t%s\t%s\n' "$p" "${SZ[$p]:-0}" "${MT[$p]:-0}" >> "$m.tmp.$$"
            done
            mv "$m.tmp.$$" "$m"
            cp "$m" "$done_dir/${h}-${stamp}-partial.tsv"
        fi
        if (( ${#conf[@]} > 0 )); then
            for p in "${conf[@]}"; do
                printf '%s\tlocal=%s\tnas=%s\n' "$p" "$(stat -c %Y -- "$HOME/$p")" "${MT[$p]:-0}"
            done > "$done_dir/${h}-${stamp}.conflicts"
        fi
    fi

    total_pulled=$(( total_pulled + ${#pulled[@]} ))
    total_conf=$(( total_conf + ${#conf[@]} ))
    total_failed=$(( total_failed + ${#failed[@]} ))
    total_same=$(( total_same + ${#same[@]} ))
done

{
    printf -- '------------------------------------------------------------------------\n'
    printf 'Summary: %d pulled, %d conflict(s) kept local, %d failed, %d unchanged.\n' \
           "$total_pulled" "$total_conf" "$total_failed" "$total_same"
} >> "$REPORT"
mv "$REPORT" "$LOG"
(( QUIET )) || cat "$LOG"

if (( TERMINAL && total_pulled + total_conf + total_failed > 0 )) &&
   [[ -n ${WAYLAND_DISPLAY:-}${DISPLAY:-} ]]; then
    open_report_terminal "$LOG"
fi

(( total_failed > 0 )) && exit 1
exit 0
