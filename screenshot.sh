#!/bin/bash

if [[ $XDG_SESSION_TYPE == "x11" ]]; then
   maim --hidecursor --highlight --tolerance=0 --color=0.5,0.5,0.5,0.6 -s --noopengl --bordersize=3 ~/DCIM/Screenshots/$(date +%Y-%m-%d-%H-%M-%S_maim | tr A-Z a-z).jpg
fi

if [[ $XDG_SESSION_TYPE == "wayland" ]]; then
   # original command
   # grim -t jpeg -g "$(slurp)" ~/DCIM/Screenshots/$(date +'%Y-%m-%d-%H-%M-%S.jpg')
   # advent calendar ratio
   # slurp -a 600:420 -d | grim -g - ~/DCIM/Screenshots/$(date +'%Y-%m-%d-%H-%M-%S.jpg')
   slurp -d | grim -g - ~/DCIM/Screenshots/$(date +'%Y-%m-%d-%H-%M-%S.jpg')
fi
