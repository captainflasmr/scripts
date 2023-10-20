#!/bin/bash
# copy video image files from tablet
SRC="$HOME/Downloads"
DST="$HOME/KritaRecorder"

SRCZIPS=$(find $SRC -maxdepth 1 -mindepth 1 -type f -regextype sed -regex '^.*\/[0-9]\{14\}.zip$' -printf '%f\n')

echo "Copying Krita videos..."

cd "$SRC"

for A in $SRCZIPS; do
   DIR=${A%.*}

   echo "Unzipping $SRC/$A ..."
   unzip $SRC/$A
   chmod -R 777 $SRC/$DIR

   echo "Doing $DIR ..."
   if [[ -d "$DST/$DIR" ]]; then
      SRCFILES=$(find "$SRC/$DIR" -maxdepth 1 -type f -regextype sed -regex '^.*\/[0-9]\{7\}.jpg$' | sort)
      LASTNUM=$(find "$DST/$DIR" -maxdepth 1 -type f -regextype sed -regex '^.*\/[0-9]\{7\}.jpg$' | sort | tail -n1)

      LASTNUM=${LASTNUM##*/}
      LASTNUM=10#${LASTNUM%.*}

      for FILE in $SRCFILES; do
         ((LASTNUM++))
         NEWFILE=$(printf "%07d" $LASTNUM).jpg
         echo "$FILE -> $DIR/$NEWFILE"
         cp "$FILE" "$DST/$DIR/$NEWFILE"
      done
   else
      echo "$DST/$DIR just copying files..."
      echo "$SRC/$DIR -> $DST/$DIR"
      cp -r "$SRC/$DIR" "$DST/$DIR/$NEWFILE"
   fi
done
