#!/bin/bash

DST=$HOME/.config

# Set keyboard layout to British
setxkbmap gb

# Apply sticky modifier changes and save to a specific file
xkbcomp $DISPLAY -xkb - | \
sed 's|SetMods|LatchMods|g' > \
$DST/keymap_with_sticky_modifiers.xkb

# Reset keyboard layout to British
setxkbmap gb

# Apply locked modifiers changes and save to a specific file
xkbcomp $DISPLAY -xkb - | \
sed 's|SetMods|LatchMods|g' | \
sed 's|,clearLocks);|,clearLocks,latchToLock);|g' > \
$DST/keymap_with_locked_modifiers.xkb
