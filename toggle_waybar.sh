#!/bin/bash

# Waybar toggle script

# Determine if Waybar is running
if pgrep -x waybar > /dev/null; then
    # If Waybar is running, kill it
    killall waybar
else
    # If Waybar is not running, start it
    waybar &
fi
