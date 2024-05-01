#!/bin/bash

# Define the paths to your keymap files
KEYMAP_SWAY=~/.config/keymap_sway.xkb
KEYMAP_LOCKED=~/.config/keymap_with_locked_modifiers.xkb
KEYMAP_STICKY=~/.config/keymap_with_sticky_modifiers.xkb
CURRENT_KEYMAP_PATH=~/.config/keymap_current

# Check if the current keymap is set, if not use the sway keymap
if [[ ! -f "$CURRENT_KEYMAP_PATH" ]]; then
   echo "$KEYMAP_SWAY" > "$CURRENT_KEYMAP_PATH"
fi

CURRENT_KEYMAP=$(cat "$CURRENT_KEYMAP_PATH")

# Swap the keymaps
if [[ "$CURRENT_KEYMAP" = "$KEYMAP_LOCKED" ]]; then
   cp -f "$KEYMAP_STICKY" "$KEYMAP_SWAY"
   echo "$KEYMAP_STICKY" > "$CURRENT_KEYMAP_PATH"
else
   cp -f "$KEYMAP_LOCKED" "$KEYMAP_SWAY"
   echo "$KEYMAP_LOCKED" > "$CURRENT_KEYMAP_PATH"
fi

# Reload Sway configuration
swaymsg reload
