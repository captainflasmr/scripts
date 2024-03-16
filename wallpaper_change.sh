#!/bin/bash

if [[ $XDG_SESSION_TYPE == "x11" ]]; then
   # feh --bg-scale "$(find ~/wallpaper -type f | shuf -n 1)"
   wallpaper_path="$(find ~/wallpaper -type f | shuf -n 1)"
   echo $wallpaper_path > ~/.last_wallpaper_path
   feh --bg-scale "$wallpaper_path"
fi

if [[ $XDG_SESSION_TYPE == "wayland" ]]; then
   swww img $(find ~/wallpaper -type f | shuf -n 1) --transition-step 20 --transition-fps=20
fi
