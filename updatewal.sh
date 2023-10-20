#!/bin/bash
echo "Changing theme..."

# -----------------------------------------------------
# Update Wallpaper with pywal
# -----------------------------------------------------
wal -q -i ~/wallpaper/

# -----------------------------------------------------
# Wait for 1 sec
# -----------------------------------------------------
sleep 1

# -----------------------------------------------------
# Reload qtile to color bar
# -----------------------------------------------------
qtile cmd-obj -o cmd -f reload_config

# -----------------------------------------------------
# Get new theme
# -----------------------------------------------------
source "$HOME/.cache/wal/colors.sh"
newwall=$(echo $wallpaper | sed "s|$HOME/wallpaper/||g")

# -----------------------------------------------------
# Send notification
# -----------------------------------------------------
notify-send "Theme and Wallpaper updated" "With image $newwall"

echo "Done."
