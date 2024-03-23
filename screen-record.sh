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

if [[ $XDG_SESSION_TYPE == "wayland" ]]; then
   # Note : to get the audio device run: pactl list sources
   # | grep -i "Name" and choose the first line staring with
   # Name which will be the very long name!  oh and if you
   # are not sure which audio device is coming out of then
   # use pavucontrol
   pid=`pgrep wf-recorder`
   status=$?

   if [ $status != 0 ]
   then
      # wf-recorder \
      #    --audio="alsa_output.usb-Synaptics_Hi-Res_Audio_000000000000000000000000-00.analog-stereo.monitor" \
      #    -f "$DST"/$DATE--screen-recording.mp4 -F fps=5
      wf-recorder \
         --audio="alsa_output.usb-Synaptics_Hi-Res_Audio_000000000000000000000000-00.analog-stereo.monitor" \
         -f "$DST"/$DATE--screen-recording.mkv -F fps=5
   else
      pkill --signal SIGINT wf-recorder
   fi;
else
   pid=`pgrep ffmpeg`
   status=$?

   if [ $status != 0 ]
   then
      ffmpeg -video_size 1920x1080 -framerate 10 \
             -f x11grab -i :0.0+0,0 -c:v libx264rgb -crf 23 \
             -preset ultrafast "$DST"/$DATE--screen-recording.mp4
   else
      pkill --signal SIGINT ffmpeg
   fi;
fi
