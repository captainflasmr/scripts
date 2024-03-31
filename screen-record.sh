#!/bin/bash
# ~/.config/kwinrc
# [Compositing]
# AllowTearing=true
# GLCore=false
# GLTextureFilter=1
# HiddenPreviews=4
# LatencyPolicy=ExtremelyLow
# OpenGLIsUnsafe=false
DATE=$(date +%Y%m%d%H%M%S)
DST=~/Videos
# for sway
if [[ $XDG_SESSION_TYPE == "wayland" ]]; then
   wf-recorder -f "$DST"/$DATE--screen-recording.mp4 -F fps=10
else
   # for X11 only
   ffmpeg -video_size 1920x1080 -framerate 10 -f x11grab -i :0.0+0,0 -c:v libx264rgb -crf 23 -preset ultrafast "$DST"/$DATE--screen-recording.mp4
fi
