#!/bin/bash

# wayland
touch_wayland="1267:16491:ELAN902C:00_04F3:406B"

# lets make sure everything is killed
KILL_LIST="fusuma \
gammastep-indicator toggle_wlr_keyboard.sh launch_waybar waybar \
polkit-gnome-authentication-agent-1 kmonad \
ydotoold syncthing dunst autotiling udiskctrl wvkbd-mobintl battery-monitor.sh"

killall -q $KILL_LIST

if [[ $XDG_SESSION_TYPE == "wayland" ]]; then
    toggle_wlr_keyboard.sh
    launch_waybar &
    sway-audio-idle-inhibit &
    swaybg -i ~/.last_wallpaper.jpg &
    dunst &
fi

kdeconnectd &
kdeconnect-indicator &
nm-applet --indicator &
/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
ydotoold --socket-perm 0777 --socket-path=/run/user/1000/.ydotool_socket &
syncthing -no-browser -no-browser -home="/home/jdyer/.config/syncthing" &
autotiling &
sleep 2
udisksctl mount -b /dev/mmcblk0p1 # SD Card
# udisksctl mount -b /dev/sda1
# Hopefully now handled by fstab
# UUID=7FBD-D459                            /mnt/local     exfat   rw,nofail,noatime,exec,uid=1000,gid=1000 0 0
udisksctl mount -b /dev/sdb1
battery-monitor.sh &

NUMPAD_CONNECTED=0
KEYBOARD_CONNECTED=0

ollama serve &

while :
do
   if [[ -L "/dev/input/by-id/usb-SEMICO_USB_Gaming_Keyboard-event-kbd" ]]; then
      if [[ $KEYBOARD_CONNECTED == 0 ]]; then
         KEYBOARD_CONNECTED=1
         # notify-send -t 3000 "KEYBOARD CONNECTED!"
         swaymsg input 1:1:AT_Translated_Set_2_keyboard events disabled
      fi
   else
      if [[ $KEYBOARD_CONNECTED == 1 ]]; then
         KEYBOARD_CONNECTED=0
         # notify-send -t 3000 "KEYBOARD DISCONNECTED!"
         swaymsg input 1:1:AT_Translated_Set_2_keyboard events enabled
      fi
   fi

   # if [[ -L "/dev/input/by-id/usb-13ba_0001-event-kbd" ]]; then
   if [[ -L "/dev/input/by-id/usb-CX_2.4G_Wireless_Receiver-event-kbd" ]]; then
      if [[ $NUMPAD_CONNECTED == 0 ]]; then
         setxkbmap gb
         NUMPAD_CONNECTED=1
         # notify-send -t 3000 "NUMPAD CONNECTED!"
         swaymsg input "$touch_wayland" events disabled
         kmonad ~/.config/kmonad/numpad.kbd &
      fi
   else
      if [[ $NUMPAD_CONNECTED == 1 ]]; then
         keymap-load.sh
         NUMPAD_CONNECTED=0
         # notify-send -t 3000 "NUMPAD DISCONNECTED!"
         swaymsg input "$touch_wayland" events enabled
         killall -q kmonad
      fi
   fi
   sleep 2
done
