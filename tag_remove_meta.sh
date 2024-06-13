#!/bin/bash

FILES=$(find $PWD -iname '*.jpg' | tr '\n' ' ')

source Common.sh "$FILES"

for A in $FILES; do
   pre
   exiftool -IPTC= -XMP= -preserve "$A"
done
