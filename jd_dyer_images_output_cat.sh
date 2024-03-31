#! /bin/bash

function resize_images() {
   cd $SRC
   FILES=$(find $SRC \( -exec [ -f {}/.nomedia ] \; -prune \) -o -iname '*.jpg' -printf '%p;')
   source Common.sh $FILES
   for A in $FILES; do
      pre
      printf "${tags}\n"
   done
}

LIST="doodles animals got landscapes monsters portraits stilllife buffy kate misc starwars superhero old"
export IFS=" "
for DIR in $LIST; do
   SRC="$HOME/Photos/Gallery/${DIR}"
   # DST="$HOME/DCIM/content/art--gallery/${DIR}"
   # DST="/run/media/jdyer/6665-3063/img-cat"
   DST="/home/jdyer/DCIM/content/tagged"
   # rm -fr $DST/*.jpg
   resize_images
done

LIST="album1 album2 album3 album4 babybooks cards certificates graduation misc originals transformers"
export IFS=" "
for DIR in $LIST; do
   SRC="$HOME/Photos/Scans/${DIR}"
   # DST="$HOME/DCIM/content/scans/${DIR}"
   # DST="/run/media/jdyer/6665-3063/img-cat"
   DST="/home/jdyer/DCIM/content/tagged"
   # rm -fr $DST/*.jpg
   resize_images
done

export IFS=" "
for DIR in {2003..2023}; do
   SRC="$HOME/Photos/${DIR}"
   # DST="$HOME/DCIM/content/photos/${DIR}"
   # DST="/run/media/jdyer/6665-3063/img-cat"
   DST="/home/jdyer/DCIM/content/tagged"
   # rm -fr $DST/*.jpg
   resize_images
done
