#!/bin/bash

wallpaper_path="$(find ~/wallpaper/transformers -type f | shuf -n 1)"

# Save current wallpaper as previous before overwriting
if [ -f ~/.last_wallpaper_path ]; then
    cp ~/.last_wallpaper_path ~/.previous_wallpaper_path
fi

echo $wallpaper_path > ~/.last_wallpaper_path
cp -f $wallpaper_path ~/.last_wallpaper.jpg

if [[ $XDG_SESSION_TYPE == "wayland" ]]; then
    pkill swaybg
    swaybg -i "$wallpaper_path" -m fill &
fi

# lets run pywal for colour scheme generation
wal -c
# wal -i ~/.last_wallpaper.jpg -q -n 2>&1 /dev/null
wal -i ~/.last_wallpaper.jpg -q -n

# Load colors from pywal
colors=$(cat ~/.cache/wal/colors.json)

fg=$(echo $colors | jq -r '.special.foreground')
bg=$(echo $colors | jq -r '.special.background')
c1=$(echo $colors | jq -r '.colors.color1')
c4=$(echo $colors | jq -r '.colors.color4')
c5=$(echo $colors | jq -r '.colors.color5')
c6=$(echo $colors | jq -r '.colors.color6')
c8=$(echo $colors | jq -r '.colors.color8')

# Update sway window decorations
swaymsg client.focused          "$fg" "$bg" "$fg" "$c5" "$c6"
swaymsg client.focused_inactive "#666666" "#2a2a2a" "#888888" "#666666" "#666666"
swaymsg client.unfocused         "#555555" "#222222" "#777777" "#555555" "#555555"
swaymsg client.urgent            "$c1" "$c1" "$bg" "$fg" "$c1"
