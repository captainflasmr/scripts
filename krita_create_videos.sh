#!/bin/bash
# create videos from krita directories

MYDATE=`date +%Y%m%d%H%M%S`

SRC="$HOME/KritaRecorder"
DEST="$HOME/Videos/Art"
PADDIR="pad"

REGENALL=0

DIRS=$(find $SRC -maxdepth 1 -mindepth 1 -type d -regextype sed -regex '^.*\/[0-9]\{14\}$' -printf '%f\n')

echo "Generating Krita videos..."

mkdir -p "$DEST"

if [[ $REGENALL == 1 ]]; then
   find . -type d -name "pad" -exec rm -fr {} +
fi

for A in $DIRS; do
   REGENVID=0
   cd "$SRC/$A"
   mkdir -p $PADDIR

   FILES=$(find . -maxdepth 1 -type f -regextype sed -regex '^.*\/[0-9]\{7\}.jpg$' | sort)

   for FILE in $FILES; do
      if [[ ! -f "$PADDIR/$FILE" ]]; then
         echo "$A/$FILE"
         REGENVID=1
         convert $FILE -resize 1280x720 -background black -gravity center \
                 -extent 1280x720 "$PADDIR/$FILE"
      fi
   done

   if [[ $REGENVID == 1 ]]; then
      echo "Generating $DEST/$A.mp4 ..."
      ffmpeg -hide_banner -loglevel panic -stats \
             -y -start_number 0 -i "$PADDIR/%7d.jpg" -c:v libx264 -vf \
             "fps=10,format=yuv420p" "$DEST/$A.mp4"
   fi
done
