#!/bin/bash

FILES=$(find $PWD -iname '*.jpg' | tr '\n' ' ')

source Common.sh "$FILES"

for A in $FILES; do
   #    pre
   exiftool -orientation#=1 -overwrite_original_in_place "-FileModifyDate<DateTimeOriginal" "-FileModifyDate<CreateDate" "$A"
done
