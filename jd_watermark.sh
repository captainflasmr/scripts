#! /bin/bash
# Resize images and apply a watermark

function resize_images() {
   cd $SRC

   DIRLIST=$(find . \( -exec [ -f {}/.nomedia ] \; -prune \) -o -type d -print)
   LIST=$(find . \( -exec [ -f {}/.nomedia ] \; -prune \) -o -iname "*.jpg" -print)

   # create the dirs
   for dir in $DIRLIST; do
      if [[ ! -d "$DEST/${dir}" ]]; then
         mkdir -p $DEST/$dir
      fi
   done

   # convert the files and copy over
   for file in $LIST; do
      #	if [[ ! -f "$DEST/${file}" ]]; then
      echo "$DEST/${file}"

      BASE=${file%.*}
      EXT="jpg"

      #	    convert TerryPratchett\[art-noprint-portraits\].jpg \( ../../watermark.png -background transparent -rotate 315 -alpha set -channel a -evaluate multiply 0.2 \) -strip -quality 50% -resize '1024x>' -resize 'x768>' -gravity center -compose over -composite ../../watermark.png out.jpg

      convert "${file}" \( $HOME/Pictures/watermark.png -alpha set -channel a -evaluate multiply 0.2 -background none -rotate 315 \) -auto-orient -strip -quality 50% -resize '600x>' -resize 'x600>' -gravity center -compose over -composite $HOME/Pictures/watermark.png "$DEST/${file}"
      mv "$DEST/${BASE}-0.${EXT}" "$DEST/${file}"
      rm -f "$DEST/${BASE}-1.${EXT}"
      #	fi
   done

   # delete any empty directories
   find "$DEST" -type d -empty -delete
}

SRC="$HOME/Photos/Gallery"
DEST="$HOME/Pictures/Etsy/Art"
resize_images
