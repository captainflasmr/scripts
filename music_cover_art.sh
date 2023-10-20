#!/bin/bash
DIRS=$(find "/home/jdyer/MyMusicLibrary" -type d -printf '%p;')

export IFS=";"

for dir in $DIRS; do
   cd "$dir"
   files=(*)
   if [[ ${files[0]: -4} == ".mp3" ]]; then
      echo $dir
      ffmpeg -hide_banner -loglevel panic -stats -y \
             -i "${files[0]}" -an -c:v copy "$dir/cover.jpg"
      convert -resize 80x80 "$dir/cover.jpg" "$dir/cover.jpg"
      exiftool -overwrite_original_in_place "-CreateDate=1980:01:01 00:00:00" "-FileModifyDate=1980:01:01 00:00:00" "$dir/cover.jpg"
   fi
done
