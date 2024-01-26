#!/bin/bash
# script to sync a local updated MyMusicLibrary

SRC=$HOME/MyMusicLibrary
DIRS=$(ls $SRC)

function do_sync ()
{
   for DIR in $DIRS; do
      echo "$SRC/$DIR -> $1/$DIR"
      rsync -arz --no-g --modify-window=4 "$SRC/$DIR/" "$1/$DIR/"
   done
}

# clipjam
do_sync /run/media/jdyer/EOS_DIGITAL/MyMusicLibrary

# pro2 sd card
# do_sync /run/media/jdyer/6665-3063/MyMusicLibrary

# nas
# do_sync $HOME/nas/Music/MyMusicLibrary
