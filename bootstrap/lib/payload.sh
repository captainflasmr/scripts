#!/usr/bin/env bash
# payload.sh - single source of truth for "what counts as my data".
# Sourced by do_backup (push to NAS), sync-from-nas.sh (pull from NAS) and
# refresh-usb.sh (push to stick) so every direction agrees on the data set.
#
# Two layers:
#   • FULL set   - home-include.txt / home-exclude.txt, the complete home that
#                  do_backup mirrors to the NAS and 'sync-from-nas --full' pulls
#                  back. Plain rsync --files-from / --exclude-from files so rsync
#                  consumes them directly; this script also reads them into the
#                  HOME_FULL / HOME_EXCLUDES arrays for callers that want bash.
#   • Curated    - the small, deliberate subset that goes on a portable USB
#                  install stick (refresh-usb.sh). Intentionally omits the big,
#                  machine-specific dirs (.local, Videos, Applications, …).

# resolve our own dir so the .txt files are found wherever the repo lives
PAYLOAD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_INCLUDE_FILE="$PAYLOAD_DIR/home-include.txt"   # rsync --files-from
HOME_EXCLUDE_FILE="$PAYLOAD_DIR/home-exclude.txt"   # rsync --exclude-from

# FULL home as a bash array (paths, comments/blanks stripped).
HOME_FULL=()
if [[ -r $HOME_INCLUDE_FILE ]]; then
    while IFS= read -r _l; do
        [[ -z $_l || $_l == \#* ]] && continue
        HOME_FULL+=("$_l")
    done < "$HOME_INCLUDE_FILE"
fi

# Exclusions as ready-made rsync args: HOME_EXCLUDES=(--exclude P --exclude Q …).
# Equivalent to --exclude-from=$HOME_EXCLUDE_FILE, for callers that build an
# rsync argv array (refresh-usb, sync-from-nas).
HOME_EXCLUDES=()
if [[ -r $HOME_EXCLUDE_FILE ]]; then
    while IFS= read -r _l; do
        [[ -z $_l || $_l == \#* || $_l == \;* ]] && continue
        HOME_EXCLUDES+=(--exclude "$_l")
    done < "$HOME_EXCLUDE_FILE"
fi
unset _l

# --- curated USB-stick subset (deliberately small; edit by hand) ----------
# Paths (relative to $HOME) copied into <stick>/home/. refresh-usb.sh feeds
# these to rsync via --files-from with the shared home-exclude.txt, so nested
# paths (e.g. .local/share/opencode) keep their layout and the same exclude
# patterns apply as on the NAS backup.
HOME_INCLUDE=( .config bin scripts .emacs.d .thunderbird
               .profile .bashrc .bash_profile .bash_logout .gitconfig .ignore
               .claude .claude.json .local/share/opencode )
# Secrets bundled into the encrypted archive (relative to $HOME).
SECRET_INCLUDE=( .ssh .gnupg .authinfo .authinfo.gpg )
# Bulk data dirs copied into <stick>/data/ (relative to $HOME).
DATA_DIRS=( DCIM source wallpaper Maildir )
