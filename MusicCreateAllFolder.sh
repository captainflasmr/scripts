#!/bin/bash

# SRC=/run/media/jdyer/EOS_DIGITAL/MyMusicLibrary
# DST=/run/media/jdyer/EOS_DIGITAL/MyMusicLibraryAll

SRC=/run/media/jdyer/6665-3063/MyMusicLibrary
DST=/run/media/jdyer/6665-3063/MyMusicLibraryAll

FILES=$(find "$SRC" -type f -iname "*.mp3")

source Common.sh $FILES

for A in $FILES; do
   pre
   if [[ ! -f "${DST}/$FILE" ]]; then
      echo "${DST}/$FILE"
      cp "$A" "${DST}/$FILE"
   fi
done
