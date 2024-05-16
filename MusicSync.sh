#!/bin/bash
# script to sync a local updated MyMusicLibrary

SRC="$HOME/nas/Music/MyMusicLibrary"

declare -a DESTINATIONS=(
    "/run/media/jdyer/EOS_DIGITAL/MyMusicLibrary"
    "/run/media/jdyer/MusicLib/MyMusicLibrary"
    "/run/media/jdyer/PhoneSD/MyMusicLibrary"
    "/run/media/jdyer/6665-3063/MyMusicLibrary"
    "/run/media/jdyer/SPORT GO/Music/MyMusicLibrary"
)

function do_sync() {
    rsync -arz --delete --no-g --modify-window=4 "$SRC/" "$1/"
}

for DEST in "${DESTINATIONS[@]}"; do
    if [[ -d "$DEST" ]]; then
        echo "Syncing to $DEST..."
        do_sync "$DEST"
    else
        echo "$DEST not present."
    fi
done
