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

fg=$(echo $colors | jq -r '.special.foreground')
bg=$(echo $colors | jq -r '.special.background')
c1=$(echo $colors | jq -r '.colors.color1')
c4=$(echo $colors | jq -r '.colors.color4')
c5=$(echo $colors | jq -r '.colors.color5')
c6=$(echo $colors | jq -r '.colors.color6')
c8=$(echo $colors | jq -r '.colors.color8')

# Update sway window decorations
swaymsg client.focused          "$fg" "$bg" "$fg" "$c5" "$c6"
swaymsg client.focused_inactive "$c8" "$bg" "$c8" "$c4" "$c4"
swaymsg client.unfocused         "$c8" "$bg" "$c8" "$c4" "$c4"
swaymsg client.urgent            "$c1" "$c1" "$bg" "$fg" "$c1"
