#! /bin/bash

PHOTOS_SRC="/run/media/jdyer/Backup/Photos"

function resize_images() {

   cd $SRC

   FILES=$(find $SRC \( -exec [ -f {}/.nomedia ] \; -prune \) -o -iname '*.jpg' -printf '%p;')

   source Common.sh $FILES

   mkdir -p "$DST"

   for A in $FILES; do
      pre
      # enable switching between jpg and webp
      EXTOLD=webp
      EXT=jpg
      NEWFILE="${DST}/${FILE_NO_EXT}.${EXT}"
      if [[ ! -f "${NEWFILE}" ]]; then
         printf "${NEWFILE} \n"
         # magick "$A" -auto-orient -strip -quality 30% -resize '1024x>' -resize 'x1024>' "${NEWFILE}"
         magick "$A" -auto-orient -strip -quality 40% -resize '768x>' -resize 'x768>' "${NEWFILE}"
         # apply meta data (will take longer)
         exiftool -overwrite_original -TagsFromFile "$A" "${NEWFILE}"
         touch -r "$A" "${NEWFILE}"
      fi
   done
}

LIST="doodles animals got landscapes monsters portraits stilllife buffy kate misc starwars superhero old"
export IFS=" "
echo
echo "Doing Art..."
echo
for DIR in $LIST; do
   echo $DIR
   SRC="${PHOTOS_SRC}/Gallery/${DIR}"
   DST="$HOME/DCIM/content/art--gallery/${DIR}"
   # rm -fr $DST/*.jpg
   resize_images
done

LIST="album1 album2 album3 album4 babybooks cards certificates graduation misc originals transformers"
export IFS=" "
echo
echo "Doing Scans..."
echo
for DIR in $LIST; do
   echo $DIR
   SRC="${PHOTOS_SRC}/Scans/${DIR}"
   DST="$HOME/DCIM/content/scans/${DIR}"
   # rm -fr $DST/*.jpg
   resize_images
done

export IFS=" "
echo
echo "Doing Photos..."
echo
for DIR in {2023..2024}; do
   echo $DIR
   SRC="${PHOTOS_SRC}/${DIR}"
   DST="$HOME/DCIM/content/photos/${DIR}"
   # rm -fr $DST/*.jpg
   resize_images
done
