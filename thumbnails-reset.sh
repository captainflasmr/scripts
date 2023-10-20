#!/bin/bash
SRC="/home/jdyer/.cache/thumbnails"
DIRS="large normal x-large xx-large"

for dir in $DIRS; do
   rm -f $SRC/$dir/*
done
