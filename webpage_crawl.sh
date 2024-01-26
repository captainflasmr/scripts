#!/bin/bash
# this script crawls the input website

# get just the images recursively
# wget --random-wait --limit-rate=100k -r -A=.jpg,.png "$1"
# wget -A=.jpg,.png "$1"

# get whole web page recursively
wget --recursive \
     --span-hosts \
     --timeout=2 \
     --tries=2 \
     --no-clobber \
     --page-requisites \
     --html-extension \
     --convert-links \
     --no-parent \
     "$1"
