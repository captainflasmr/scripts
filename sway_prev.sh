#!/bin/bash

# Get the ID of the currently focused window
focused=$(swaymsg -t get_tree | jq '.. | select(.focused? == true).id')

# Try to focus the left window
swaymsg focus left

# Check if the focused window is still the same
new_focused=$(swaymsg -t get_tree | jq '.. | select(.focused? == true).id')

# If it did not find a window to the left, move to the next workspace
if [ "$focused" == "$new_focused" ]; then
    current_workspace=$(swaymsg -t get_outputs -r | jq -r '.[] | select(.focused) .current_workspace')

    # Increment the workspace number or set any custom logic you need here, e.g., moving to the next integer workspace
    next_workspace=$(($current_workspace - 1))

    # Move to the next workspace
    swaymsg workspace number $next_workspace
fi
