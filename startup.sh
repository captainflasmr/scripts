#!/bin/bash

sleep 2

if [[ $XDG_SESSION_TYPE == "x11" ]]; then
   if ! pgrep "^sxhkd$" >/dev/null; then
      /usr/bin/sxhkd &
   fi
   xinput set-prop "ZNT0001:00 14E5:E545 Touchpad" "libinput Natural Scrolling Enabled" 1
   xinput set-prop "ZNT0001:00 14E5:E545 Touchpad" "libinput Accel Speed" 0.8
   touch_disable.sh
fi

if ! pgrep "^kmonad$" >/dev/null; then
   kmonad ~/.config/kmonad/keyboard.kbd &
   kmonad ~/.config/kmonad/numpad.kbd &
fi

if ! pgrep "^syncthing$" >/dev/null; then
   /usr/bin/syncthing -no-browser -no-browser -home="/home/jdyer/.config/syncthing" &
fi

if ! pgrep "^fusuma$" >/dev/null; then
   /usr/bin/fusuma -d
fi

if ! pgrep "^dunst$" >/dev/null; then
   dunst &
fi

if ! pgrep "^autotiling$" >/dev/null; then
   autotiling &
fi
