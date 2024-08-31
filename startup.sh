#!/bin/bash
# x11
touchpad_x11="ZNT0001:00 14E5:650E Touchpad"
touch_x11="ELAN902C:00 04F3:406B"
# wayland
touch_wayland="1267:16491:ELAN902C:00_04F3:406B"

# lets make sure everything is killed
KILL_LIST="redshift fusuma launch_polybar polybar picom \
gammastep-indicator toggle_wlr_keyboard.sh launch_waybar waybar \
swww polkit-gnome-authentication-agent-1 kmonad \
ydotoold syncthing dunst autotiling udiskctrl wvkbd-mobintl battery-monitor.sh"

killall -q $KILL_LIST

if [[ $XDG_SESSION_TYPE == "x11" ]]; then
   feh --bg-scale "$(cat ~/.last_wallpaper_path)"
   xinput set-prop "$touchpad_x11" "libinput Natural Scrolling Enabled" 1
   xinput set-prop "$touchpad_x11" "libinput Accel Speed" 0.8
   # redshift -l 51.0:-1.0 -t 5700:3600 &
   fusuma -d
   if [[ ! $XDG_CURRENT_DESKTOP == "KDE" ]]; then
      launch_polybar &
      picom -c &
   fi
   xset b off
fi

if [[ $XDG_SESSION_TYPE == "wayland" ]]; then
   if [[ ! $XDG_CURRENT_DESKTOP == "KDE" ]]; then
      # gammastep-indicator &
      toggle_wlr_keyboard.sh
      launch_waybar &
      sway-audio-idle-inhibit &
      # DEPRECATION WARNING: `swww init` IS DEPRECATED. Call `swww-daemon` directly instead
      swww-daemon &
      dunst &
   fi
fi

# xremap ~/.config/xremap/emacs.yml &

kdeconnectd &
kdeconnect-indicator &
nm-applet --indicator &
/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
ydotoold --socket-perm 0777 --socket-path=/run/user/1000/.ydotool_socket &
syncthing -no-browser -no-browser -home="/home/jdyer/.config/syncthing" &
autotiling &
udisksctl mount -b /dev/mmcblk0p1 # SD Card
udisksctl mount -b /dev/sda1 # Attached VM drive
battery-monitor.sh &

NUMPAD_CONNECTED=0
KEYBOARD_CONNECTED=0

keymap-load.sh

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
