#!/bin/bash

if [[ $XDG_SESSION_TYPE == "wayland" ]]; then
   if pgrep -x "^wf-recorder$"  > /dev/null; then
      # echo '{"text": "📽️ REC", "class": "recording"}'
      echo '{"text": " REC", "class": "recording"}'
   else
      # echo '{"text": "📽️", "class": "not-recording"}'
      echo '{"text": "", "class": "not-recording"}'
   fi
else
   if pgrep "^ffmpeg$" > /dev/null; then
      echo "REC"
   else
      echo " "
   fi
fi
