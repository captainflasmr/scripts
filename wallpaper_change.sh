#!/bin/bash

wallpaper_path="$(find ~/wallpaper -type f | shuf -n 1)"
echo $wallpaper_path > ~/.last_wallpaper_path
cp -f $wallpaper_path ~/.last_wallpaper.jpg

if [[ $XDG_SESSION_TYPE == "x11" ]]; then
    feh --bg-scale "$wallpaper_path"
fi

if [[ $XDG_SESSION_TYPE == "wayland" ]]; then
    pkill swaybg
    swaybg -i "$wallpaper_path" &
fi

# lets run pywal for colour scheme generation
wal -c
# wal -i ~/.last_wallpaper.jpg -q -n 2>&1 /dev/null
wal -i ~/.last_wallpaper.jpg -q -n

# Load colors from pywal
colors=$(cat ~/.cache/wal/colors.json)

# Extracting colors
fg=$(echo $colors | jq -r '.special.foreground')
bg=$(echo $colors | jq -r '.special.background')

# Update sway window decorations
swaymsg client.focused "$fg" "$fg" "$fg" "$fg" "$fg"
swaymsg client.focused_inactive "$bg" "$bg" "$bg" "$bg" "$bg"
