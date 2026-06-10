#!/bin/bash

wallpaper_path="$(find ~/wallpaper -type f | shuf -n 1)"

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

# lets run pywal for colour scheme generation.
# -s skips blasting OSC colour sequences at open terminals, so nothing gets
# recoloured live. Cache files (colours.json etc.) are still generated for the
# templated consumers below.
wal -c
wal -i ~/.last_wallpaper.jpg -q -n -s

# Give foot and kitty only a gentle tint of the pywal palette (mostly their own
# base). Each reloads on SIGUSR1 to pick up the regenerated theme file.
#   foot/theme.ini, kitty/theme.conf
# alacritty is deliberately left out: it keeps a static Gruvbox theme and lets
# the swayfx-blurred wallpaper seep through via its window opacity instead.
python3 ~/bin/terminal_pywal_tint.py
pkill -SIGUSR1 -x foot 2>/dev/null || true
pkill -SIGUSR1 -x kitty 2>/dev/null || true

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
