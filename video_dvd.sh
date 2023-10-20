#!/bin/bash

DIR=$1

FOUT="$DIR.mkv"

# setup output dir
TARGET="$HOME/Videos/$DIR"

mkdir -p "$TARGET"

# convert the dvd disk and put into output dir
makemkvcon --minlength=0 mkv dev:/dev/sr0 all "$TARGET"

cd "$TARGET"

# grab all the generated titles
FILES=$(find . -iname '*.mkv' | sort)

# build the concat file list for ffmpeg
for FILE in $FILES
do
   printf "file \'$FILE\'\n" >> concatlist.txt
done

# concat all titles into a single file
ffmpeg -f concat -safe 0 -i concatlist.txt -c copy -f matroska pipe:1 | ffmpeg -i pipe:0 -c:v libx264 -preset veryfast -crf 20 -profile:v main -level 4.0 -c:a copy -y "$FOUT" 2> >(tee -a ${DIR}.log)

rm concatlist.txt
