#!/bin/bash

FILES=$(find $PWD \( -exec [ -f {}/.nomedia ] \; -prune \) -o -iname '*.jpg' -printf '%p;')
# FILES=$(find $PWD -iname '*.jpg' -printf '%p;')

source Common.sh "$FILES"

for A in $FILES; do
   pre
   tags=$(exiftool -g "$A" | grep Tags);
   tags=${tags#*:}
   tags=$(echo "$tags" | tr -d ' ' | xargs)
   tags=${tags//,/-}
   tags=${tags//\//@}

   keyw=${tags//@/ }
   keyw=${keyw//-/ }
   keyw=$(echo $keyw | sed 's/ /\n/g' | sort | uniq | tr '\n' ' ' | xargs)

   CREATEDATE=$(get_date_from_file)

   if [[ $? -eq 1 ]]; then
      # only file modification date found so copy to :
      # "CreateDate" "DateTimeOriginal"
      echo "Writing : FileModifyDate to CreateDate and DateTimeOriginal"
      exiftool -all= -overwrite_original_in_place "-CreateDate<FileModifyDate" "-DateTimeOriginal<FileModifyDate" "$A"
   fi

   if [[ $? -eq 0 ]]; then
      date_time=$(echo "$CREATEDATE" | awk -F ' : ' '{print $2}')
      formatted_date_time=$(echo "$date_time" | tr -d ':' | tr -d ' ')
      formatted_date_time=${formatted_date_time%+*}

      NEWNAME="${BASEDIR}/${formatted_date_time}--${FILE_RAW}__${tags}.${EXT}"

      if [[ "$BASEDIR" != "$PREVBASEDIR" ]]; then
         echo "Checking $BASEDIR..."
      fi
      PREVBASEDIR=$BASEDIR

      # check for no tags present
      if [[ $tags == "" ]]; then
         echo "NO TAGS!! $A"
         continue
      fi

      if [[ "$NEWNAME" != "$A" ]]; then
         i=1
         until [[ ! -f "$NEWNAME" ]]; do
            NEWNAME="${BASEDIR}/${formatted_date_time}--${FILE_RAW}$((i++))__${tags}.${EXT}"
         done
         echo "----------------"
         echo "$A ->"
         echo "$NEWNAME"
         mv "$A" "$NEWNAME"
      fi
   else
      echo "#### $A NO DATE!!"
   fi
done
