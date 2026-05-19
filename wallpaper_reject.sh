#!/bin/bash

current_path=$(cat ~/.last_wallpaper_path 2>/dev/null)
previous_path=$(cat ~/.previous_wallpaper_path 2>/dev/null)

if [ -z "$current_path" ]; then
    notify-send "No wallpaper to reject"
    exit 1
fi

if [ -z "$previous_path" ]; then
    notify-send "No previous wallpaper to restore"
    exit 1
fi

if [ ! -f "$previous_path" ]; then
    notify-send "Previous wallpaper file not found: $previous_path"
    exit 1
fi

rm -f "$current_path"

echo "$previous_path" > ~/.last_wallpaper_path
cp -f "$previous_path" ~/.last_wallpaper.jpg

> ~/.previous_wallpaper_path

if [[ $XDG_SESSION_TYPE == "wayland" ]]; then
    pkill swaybg
    swaybg -i "$previous_path" &
fi

wal -c
wal -i ~/.last_wallpaper.jpg -q -n

colors=$(cat ~/.cache/wal/colors.json)
fg=$(echo $colors | jq -r '.special.foreground')
bg=$(echo $colors | jq -r '.special.background')
c1=$(echo $colors | jq -r '.colors.color1')
c4=$(echo $colors | jq -r '.colors.color4')
c5=$(echo $colors | jq -r '.colors.color5')
c6=$(echo $colors | jq -r '.colors.color6')
c8=$(echo $colors | jq -r '.colors.color8')

swaymsg client.focused          "$fg" "$bg" "$fg" "$c5" "$c6"
swaymsg client.focused_inactive "#666666" "#2a2a2a" "#888888" "#666666" "#666666"
swaymsg client.unfocused         "#555555" "#222222" "#777777" "#555555" "#555555"
swaymsg client.urgent            "$c1" "$c1" "$bg" "$fg" "$c1"

notify-send "Wallpaper rejected and deleted" "$(basename "$current_path") removed"
