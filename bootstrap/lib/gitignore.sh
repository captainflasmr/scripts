#!/usr/bin/env bash
# gitignore.sh - git-ignore handling shared by do_backup (push) and
# sync-to-nas.sh (push), extracted from do_backup so both push directions agree
# on what "the data set" means (same source of truth idea as payload.sh).
#
# Sourced by do_backup and sync-to-nas.sh. Requires git (optional: functions
# degrade to "no exclusions" when it is missing) and bash.

# rsync --include patterns for paths that are git-ignored (by nested .gitignore)
# but should still be backed up. Inserted before --exclude-from=GIT_EXCLUDE_FILE
# so rsync's "first match wins" semantics include them before the git-ignore
# exclusions. Patterns anchored to transfer root (leading '/').
GIT_INCLUDE_OVERRIDES=(
    '/.config/JetBrains/'
    '/.config/JetBrains/IntelliJIdea2026.1/**'
    # Firefox profile (modern XDG layout under ~/.config/mozilla/). Kept out of
    # the ~/.config git repo (large, holds secrets + caches); backed up via
    # override. Crash/telemetry junk pruned in home-exclude.txt.
    '/.config/mozilla/'
    '/.config/mozilla/**'
    '/.emacs.d/offline-packages/local-packages/**'
    # ~/.config is a git dotfiles repo whose .gitignore is '*' then '!dir/'.
    # '!dir/' re-includes the directory entry but NOT its contents, so when the
    # contents are untracked, 'git ls-files --ignored --directory' (run by
    # build_gitignore_excludes) lists the dir as ignored and rsync drops it.
    # These overrides re-include such dirs before --exclude-from=GIT_EXCLUDE_FILE
    # (rsync: first matching rule wins). home-exclude.txt still prunes junk inside.
    '/.config/alacritty/'
    '/.config/alacritty/**'
    '/.config/emacs/'
    '/.config/emacs/**'
    '/.config/darktable/'
    '/.config/darktable/**'
    '/.config/fish/'
    '/.config/fish/**'
    '/.config/environment.d/'
    '/.config/environment.d/**'
    '/.config/waybar/'
    '/.config/waybar/**'
    # sway/ itself is tracked, but this single config file is git-ignored.
    '/.config/sway/config.d/power_save'
    # ~/wallpaper is a git repo that tracks only its scripts/README; .gitignore
    # drops every image file. Re-include the whole tree so the wallpapers are
    # backed up, not just the git-tracked files.
    '/wallpaper/'
    '/wallpaper/**'
)

# Path to a temp file of git-derived exclude patterns, populated by
# build_gitignore_excludes() and removed by cleanup_git_excludes().
GIT_EXCLUDE_FILE=""

cleanup_git_excludes() {
    if [[ -n "$GIT_EXCLUDE_FILE" && -f "$GIT_EXCLUDE_FILE" ]]; then
        rm -f "$GIT_EXCLUDE_FILE"
    fi
    GIT_EXCLUDE_FILE=""
}

# For every git repository found under $1 (bounded depth; heavy junk dirs
# pruned), ask `git ls-files --ignored --exclude-standard` to list the paths
# git would ignore there, then emit them as rsync exclude patterns anchored to
# the transfer root ($1). Honors .gitignore at all levels, .git/info/exclude
# and core.excludesFile, with correct '!' re-include handling. Safe to run on
# non-git trees: it simply produces an empty file.
build_gitignore_excludes() {
    local root="$1"
    cleanup_git_excludes
    [[ -d "$root" ]] || return 0
    command -v git >/dev/null 2>&1 || { echo "git not found; skipping .gitignore filtering"; return 0; }

    local tmp
    tmp=$(mktemp -t gitignore-excludes.XXXXXX) || return 0

    local gitdir repo entry full rel
    # Prune node_modules/.cache/__pycache__ so the scan stays fast; prune .git
    # dirs themselves so find doesn't recurse into their (large) object store.
    while IFS= read -r -d '' gitdir; do
        repo=$(dirname "$gitdir")
        while IFS= read -r -d '' entry; do
            [[ -z "$entry" ]] && continue
            full="$repo/$entry"
            # Strip "$root/" prefix to make the path relative to SRC. Account
            # for the case where repo == root (no prefix to strip).
            if [[ "$full" == "$root/"* ]]; then
                rel=${full#"$root/"}
            else
                rel=$full
            fi
            # rsync exclude-from entries are patterns; leading '/' anchors to
            # the transfer root. Trailing '/' (dirs from --directory) is kept.
            printf '/%s\n' "$rel"
        done < <(git -C "$repo" ls-files --others --ignored --exclude-standard -z --directory 2>/dev/null)
    done < <(find "$root" -maxdepth 5 \
                \( -name node_modules -o -name .cache -o -name __pycache__ \
                   -o -name offline-packages \) -prune \
                -o -type d -name .git -prune -print0 2>/dev/null) >> "$tmp"

    if [[ -s "$tmp" ]]; then
        GIT_EXCLUDE_FILE="$tmp"
    else
        rm -f "$tmp"
        GIT_EXCLUDE_FILE=""
    fi
}
