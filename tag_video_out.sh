#!/bin/bash

FILES=$(find $PWD -iname '*.mp4' -o -iname '*.gif' | tr '\n' ' ')

source Common.sh "$FILES"

READING=0

for A in $FILES; do
   pre
   # get the tags from the sidecar file
   sc="$A.xmp"
   tagsxmp=

   if [[ -f "$sc" ]]; then
      while read line; do
         if [[ $line =~ "CatalogSets" ]]; then
            ((READING ^= 1))
         fi

         if [[ $READING == 1 ]]; then
            tagsxmp+=$(echo $line | grep :li | sed 's/<rdf:li>//g' | sed 's/<[\/]rdf:li>/-/g' | tr -d ' ' | tr '|' '@')
         fi
      done < "$sc"
      tagsxmp=${tagsxmp%*-}

      NEWNAME="${BASEDIR}/${FULLDATE}--${FILE_RAW}__${tagsxmp}.${EXT}"

      if [[ "$BASEDIR" != "$PREVBASEDIR" ]]; then
         echo "Checking $BASEDIR..."
      fi

      PREVBASEDIR=$BASEDIR

      # check for no tags present
      if [[ $tagsxmp == "" ]]; then
         echo "NO TAGS!! $A"
         continue
      fi

      if [[ "$NEWNAME" != "$A" ]]; then
         echo "--------------------------------------------------------------------------------"
         echo "$A ->"
         echo "$NEWNAME"
         mv "$A" "$NEWNAME"

         # And to copy XMP from sidecar files:
         exiftool -overwrite_original -preserve -tagsfromfile "$sc" "$NEWNAME"

         # and now move the *.xmp file as the base filename has now been renamed
         mv "$sc" "${NEWNAME}.xmp"
      fi
   fi
done
