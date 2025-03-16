#! /bin/bash

function retag_by_creation_date_images() {

   FILES=$(find $SRC \( -exec [ -f {}/.nomedia ] \; -prune \) -o -iname '*.jpg' -printf '%p;')

   source Common.sh $FILES

   for A in $FILES; do
      pre
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

         if [[ $formatted_date_time != $FILE_ONLY_TIME ]]; then
            NEWNAME="${BASEDIR}/${formatted_date_time}--${FILE_RAW}__${TAGS_RAW}.${EXT}"

            if [[ "$NEWNAME" != "$A" ]]; then
               i=1
               until [[ ! -f "$NEWNAME" ]]; do
                  NEWNAME="${BASEDIR}/${formatted_date_time}--${FILE_RAW}$((i++))__${TAGS_RAW}.${EXT}"
               done
               echo "----------------"
               echo "$A ->"
               echo "$NEWNAME"
               mv "$A" "$NEWNAME"
            fi
         else
            echo "#### $A : NO CHANGE"
         fi
      else
         echo "#### $A HAS NO EXIF DATE!!!!"
      fi
   done
}

# SRC="$HOME/Photos/2023"
# retag_by_creation_date_images

# for DIR in {2003..2023}; do
   # echo $DIR
   # SRC="$HOME/Photos/${DIR}"
   # retag_by_creation_date_images
   # done

SRC="$HOME/Photos/Gallery/misc_001/"
retag_by_creation_date_images
