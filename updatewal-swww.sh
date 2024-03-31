#!/bin/bash

# -----------------------------------------------------
# Select random wallpaper and create color scheme
# -----------------------------------------------------
wal --recursive -q -i ~/wallpaper

# -----------------------------------------------------
# Load current pywal color scheme
# -----------------------------------------------------
source "$HOME/.cache/wal/colors.sh"

# -----------------------------------------------------
# Copy color file to waybar folder
# -----------------------------------------------------
# cp ~/.cache/wal/colors-waybar.css ~/.config/waybar/

# -----------------------------------------------------
# get wallpaper iamge name
# -----------------------------------------------------
newwall=$(echo $wallpaper | sed "s|$HOME/wallpaper/||g")

# -----------------------------------------------------
# Set the new wallpaper
# -----------------------------------------------------
swww img $wallpaper --transition-step 20 --transition-fps=20

# -----------------------------------------------------
# Send notification
# -----------------------------------------------------
# notify-send "Theme and Wallpaper updated" "With image $newwall"

# echo "DONE!"
