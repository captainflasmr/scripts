#!/bin/bash
echo "Running the XKB script" >> /tmp/xkb_script.log
echo "DISPLAY=$DISPLAY" >> /tmp/xkb_script.log

if [ -z "$DISPLAY" ]; then
    export DISPLAY=:0
fi
xkbcomp $HOME/.config/keymap_with_locked_modifiers.xkb $DISPLAY
# setxkbmap -layout $HOME/.config/keymap_with_locked_modifiers.xkb -option ctrl:nocaps

echo "Setxkbmap command run" >> /tmp/xkb_script.log
