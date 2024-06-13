#! /bin/bash

function resize_images() {

   cd $SRC

   FILES=$(find $SRC \( -exec [ -f {}/.nomedia ] \; -prune \) -o -iname '*.jpg' -printf '%p;')

   source Common.sh $FILES

   mkdir -p "$DST"

   for A in $FILES; do
      pre
      for key in $keyw; do
         EXT=jpg
         NEWFILE="${DST}/${key}/${FILE_NO_EXT}.${EXT}"
         mkdir -p "${DST}/${key}"
         touch "${DST}/${key}/.nomedia"
         if [[ ! -f "${NEWFILE}" ]]; then
            # printf "$A -> ${FILE_NO_EXT}.${EXT} $key\n"
            printf "$A -> ${NEWFILE}\n"
            convert "$A" -auto-orient -strip -quality 30% -resize '1024x>' -resize 'x1024>' "${NEWFILE}"
            touch -r "$A" "${NEWFILE}"
         fi
      done
   done
}

LIST="doodles animals got landscapes monsters portraits stilllife buffy kate misc starwars superhero old"
export IFS=" "
echo
echo "Doing Art..."
echo
for DIR in $LIST; do
   echo $DIR
   SRC="$HOME/Photos/Gallery/${DIR}"
   # DST="$HOME/DCIM/content/art--gallery/${DIR}"
   # DST="/run/media/jdyer/6665-3063/img-cat"
   DST="/home/jdyer/DCIM/content/tagged"
   # rm -fr $DST/*.jpg
   # resize_images
done

LIST="album1 album2 album3 album4 babybooks cards certificates graduation misc originals transformers"
export IFS=" "
echo
echo "Doing Scans..."
echo
for DIR in $LIST; do
   echo $DIR
   SRC="$HOME/Photos/Scans/${DIR}"
   # DST="$HOME/DCIM/content/scans/${DIR}"
   # DST="/run/media/jdyer/6665-3063/img-cat"
   DST="/home/jdyer/DCIM/content/tagged"
   # rm -fr $DST/*.jpg
   # resize_images
done

export IFS=" "
echo
echo "Doing Photos..."
echo
for DIR in {2024..2024}; do
   echo $DIR
   SRC="$HOME/Photos/${DIR}"
   # DST="$HOME/DCIM/content/photos/${DIR}"
   # DST="/run/media/jdyer/6665-3063/img-cat"
   DST="/home/jdyer/DCIM/content/tagged"
   # rm -fr $DST/*.jpg
   resize_images
done
