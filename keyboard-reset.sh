#!/bin/bash

if [[ -L "/dev/input/by-id/usb-SEMICO_USB_Gaming_Keyboard-event-kbd" ]]; then
   notify-send -t 3000 "KEYBOARD CONNECTED!"
   swaymsg input 1:1:AT_Translated_Set_2_keyboard events disabled
else
   notify-send -t 3000 "KEYBOARD DISCONNECTED!"
   swaymsg input 1:1:AT_Translated_Set_2_keyboard events enabled
fi
