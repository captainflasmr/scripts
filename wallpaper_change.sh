#!/bin/bash

wallpaper_path="$(find ~/wallpaper -type f | shuf -n 1)"
echo $wallpaper_path > ~/.last_wallpaper_path
cp -f $wallpaper_path ~/.last_wallpaper.jpg

if [[ $XDG_SESSION_TYPE == "x11" ]]; then
   feh --bg-scale "$wallpaper_path"
fi

if [[ $XDG_SESSION_TYPE == "wayland" ]]; then
   # swww img "/home/jdyer/wallpaper/wallpaper-sddm.jpg" --transition-step 20 --transition-fps=20
   swww img "$wallpaper_path" --transition-step 20 --transition-fps=20
fi
