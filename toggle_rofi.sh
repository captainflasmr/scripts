#!/bin/bash
wid=$(xdotool search --class rofi)
if [[ -n $wid ]]; then
   xdotool windowactivate $wid
   xdotool key Escape
else
   rofi -show drun
fi
