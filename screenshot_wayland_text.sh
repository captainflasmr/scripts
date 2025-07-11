#!/bin/bash

# Take screenshot, run OCR, and copy to clipboard without saving file
slurp -d | grim -g - - | tesseract stdin stdout | wl-copy
notify-send "OCR" "Text copied to clipboard"
