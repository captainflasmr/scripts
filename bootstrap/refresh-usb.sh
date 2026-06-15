#!/usr/bin/env bash
# refresh-usb.sh - populate (or update) an install USB stick from THIS machine.
#
# Run on your working box, pointing at the stick's mount point:
#     ~/bin/bootstrap/refresh-usb.sh /run/media/$USER/INSTALL
#
# Produces this layout on the stick:
#     <stick>/install.sh            <- launcher (copy of bootstrap)
#     <stick>/lib/  packages/       <- the bootstrap code + package lists
#     <stick>/home/                 <- curated dotfiles + bin + config
#     <stick>/secrets.tar.gz.gpg    <- gpg-symmetric-encrypted keys
#     <stick>/data/{DCIM,source,wallpaper,Pictures}
#
# Re-running rsyncs incrementally, so updating an existing stick is cheap.
# Flags: --no-data, --no-secrets, --yes

set -uo pipefail
BOOTSTRAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$BOOTSTRAP_DIR/lib/common.sh"

# --- what to put on the stick (tweak here) --------------------------------
# Curated dotfiles/dirs copied into <stick>/home/ (relative to $HOME).
HOME_INCLUDE=( .config bin scripts .emacs.d .thunderbird
               .profile .bashrc .bash_profile .bash_logout .gitconfig .ignore )
# Secrets bundled into the encrypted archive (relative to $HOME).
SECRET_INCLUDE=( .ssh .gnupg .authinfo .authinfo.gpg )
# Bulk data dirs copied into <stick>/data/ (relative to $HOME).
DATA_DIRS=( DCIM source wallpaper Maildir )
# Excluded everywhere in the home payload (caches/junk only — .git is KEPT so
# .config and bin stay working git repos on the restored machine).
HOME_EXCLUDES=( --exclude '.cache/' --exclude '*/eln-cache/'
                --exclude '.local/share/Trash/' --exclude '*.elc' )

# --- args -----------------------------------------------------------------
DO_DATA=1; DO_SECRETS=1; NO_SOURCE=0; ASSUME_YES=0; STICK=""
for a in "$@"; do
    case "$a" in
        --no-data) DO_DATA=0 ;;
        --no-secrets) DO_SECRETS=0 ;;
        --no-source) NO_SOURCE=1 ;;
        --yes|-y) ASSUME_YES=1 ;;
        -*) die "unknown flag: $a" ;;
        *) STICK="$a" ;;
    esac
done
export ASSUME_YES
# --no-source drops the big, git-reconstructable 'source' dir from the payload.
if [[ $NO_SOURCE == 1 ]]; then
    _kept=(); for _d in "${DATA_DIRS[@]}"; do [[ $_d == source ]] || _kept+=("$_d"); done
    DATA_DIRS=("${_kept[@]}")
    info "--no-source: 'source' excluded from data payload (re-clone with install_remote.sh)"
fi
[[ -n $STICK ]] || die "usage: refresh-usb.sh [--no-data] [--no-source] [--no-secrets] <stick-mount-point>"
[[ -d $STICK ]] || die "stick path '$STICK' is not a directory (is it mounted?)"

require_cmd rsync ""
require_cmd gpg ""

section "Refreshing install USB"
info "source : $HOME"
info "target : $STICK"
df -h "$STICK" | sed 's/^/    /'
confirm "Write the install payload to $STICK?" || die "aborted"

# --- 1. bootstrap code ----------------------------------------------------
section "Copying bootstrap code"
rsync -rltP --delete \
    --exclude 'home/' --exclude 'data/' --exclude 'secrets.tar.gz.gpg' \
    "$BOOTSTRAP_DIR"/ "$STICK"/
chmod +x "$STICK"/install.sh "$STICK"/refresh-usb.sh 2>/dev/null || true

# --- 2. home payload ------------------------------------------------------
section "Copying home payload"
mkdir -p "$STICK/home"
for item in "${HOME_INCLUDE[@]}"; do
    if [[ -e $HOME/$item ]]; then
        info "home/ <- $item"
        rsync -rlptP "${HOME_EXCLUDES[@]}" "$HOME/$item" "$STICK/home/"
    else
        warn "skip (missing): $item"
    fi
done

# --- 3. secrets -----------------------------------------------------------
if [[ $DO_SECRETS == 1 ]]; then
    section "Encrypting secrets"
    present=(); for s in "${SECRET_INCLUDE[@]}"; do [[ -e $HOME/$s ]] && present+=("$s"); done
    if (( ${#present[@]} == 0 )); then
        warn "no secret files found, skipping"
    else
        info "bundling: ${present[*]}"
        # Collect the passphrase ourselves and feed gpg via loopback — avoids the
        # gpg-agent/pinentry timeout that bites under Wayland/headless shells.
        read -rs -p "Passphrase for secrets archive: " _pp1; echo
        read -rs -p "Confirm passphrase:            " _pp2; echo
        [[ -n $_pp1 && $_pp1 == "$_pp2" ]] || die "passphrases empty or did not match"
        # Stage a static copy first (excluding live gpg-agent sockets / seed / locks)
        # so nothing changes under tar while gpg is concurrently using ~/.gnupg.
        _stage=$(mktemp -d)
        _srcs=(); for s in "${present[@]}"; do _srcs+=("$HOME/$s"); done
        rsync -a --exclude='S.*' --exclude='*.lock' --exclude='random_seed' \
            "${_srcs[@]}" "$_stage/"
        if tar -czf - -C "$_stage" . \
            | gpg --batch --yes --symmetric --cipher-algo AES256 \
                  --pinentry-mode loopback --passphrase-fd 3 \
                  -o "$STICK/secrets.tar.gz.gpg" 3<<<"$_pp1"; then
            info "wrote $STICK/secrets.tar.gz.gpg"
        else
            rm -rf "$_stage"; unset _pp1 _pp2; die "encryption failed"
        fi
        rm -rf "$_stage"; unset _pp1 _pp2
    fi
fi

# --- 4. bulk data ---------------------------------------------------------
if [[ $DO_DATA == 1 ]]; then
    section "Copying bulk data"
    mkdir -p "$STICK/data"
    for d in "${DATA_DIRS[@]}"; do
        if [[ -d $HOME/$d ]]; then
            info "data/ <- $d ($(du -sh "$HOME/$d" 2>/dev/null | cut -f1))"
            rsync -rlptP --delete "$HOME/$d/" "$STICK/data/$d/"
        else
            warn "skip (missing): $d"
        fi
    done

    # DigiKam databases — small files, but restoring them means digikam
    # reads the existing catalog on first launch rather than re-scanning.
    db_files=( digikam4.db thumbnails-digikam.db similarity.db recognition.db )
    found_any=0
    for f in "${db_files[@]}"; do [[ -f $HOME/Pictures/$f ]] && found_any=1; done
    if [[ $found_any == 1 ]]; then
        mkdir -p "$STICK/data/Pictures"
        for f in "${db_files[@]}"; do
            if [[ -f $HOME/Pictures/$f ]]; then
                info "data/ <- Pictures/$f ($(du -sh "$HOME/Pictures/$f" 2>/dev/null | cut -f1))"
                rsync -ltP "$HOME/Pictures/$f" "$STICK/data/Pictures/"
            fi
        done
    else
        warn "skip: no DigiKam databases found in ~/Pictures/"
    fi
fi

sync
section "USB refresh complete"
du -sh "$STICK" 2>/dev/null | sed 's/^/    total on stick: /'
info "Safe to unmount: udisksctl unmount -b <device>  (or your file manager)"
