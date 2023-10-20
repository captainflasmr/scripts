#!/bin/bash
KEYBOARD_FILE=$HOME/KEYBOARD

if ! pgrep "^wvkbd-mobintl$" >/dev/null; then
   $HOME/repos/wvkbd/wvkbd-mobintl &
   touch $KEYBOARD_FILE
   sleep 0.1
fi

if [[ -f $KEYBOARD_FILE ]]; then
   # hide
   # killall -SIGUSR1 wvkbd-mobintl
   kill -SIGUSR1 $(pgrep wvkbd-mobintl)
   rm -f $KEYBOARD_FILE
else
   # show
   # killall -SIGUSR1 wvkbd-mobintl
   kill -SIGUSR2 $(pgrep wvkbd-mobintl)
   touch $KEYBOARD_FILE
fi
