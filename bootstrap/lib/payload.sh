#!/usr/bin/env bash
# payload.sh - single source of truth for "what counts as my data".
# Sourced by refresh-usb.sh (push to stick) and sync-from-nas.sh (pull from NAS)
# so both agree on exactly which dotfiles, secrets and bulk dirs travel.

# Curated dotfiles/dirs (relative to $HOME).
HOME_INCLUDE=( .config bin scripts .emacs.d .thunderbird
               .profile .bashrc .bash_profile .bash_logout .gitconfig .ignore )
# Secrets bundled into the encrypted archive (relative to $HOME).
SECRET_INCLUDE=( .ssh .gnupg .authinfo .authinfo.gpg )
# Bulk data dirs (relative to $HOME).
DATA_DIRS=( DCIM source wallpaper Maildir )
# Excluded everywhere in the home payload (caches/junk only — .git is KEPT so
# .config and bin stay working git repos on the restored machine).
HOME_EXCLUDES=( --exclude '.cache/' --exclude '*/eln-cache/'
                --exclude '.local/share/Trash/' --exclude '*.elc' )
