#!/bin/bash
sleep 2

# x11
touchpad_x11="ZNT0001:00 14E5:650E Touchpad"
touch_x11="ELAN902C:00 04F3:406B"
# wayland
touch_wayland="1267:16491:ELAN902C:00_04F3:406B"

# lets make sure everything is killed
KILL_LIST="redshift fusuma launch_polybar polybar picom \
gammastep-indicator toggle_wlr_keyboard.sh launch_waybar waybar \
swww polkit-gnome-authentication-agent-1 kmonad \
ydotoold syncthing dunst autotiling udiskctrl wvkbd-mobintl"

killall -q $KILL_LIST

if [[ $XDG_SESSION_TYPE == "x11" ]]; then
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
      swww init
      dunst &
   fi
fi

nm-applet --indicator &
/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
kmonad ~/.config/kmonad/keyboard.kbd &
ydotoold --socket-perm 0777 --socket-path=/run/user/1000/.ydotool_socket &
syncthing -no-browser -no-browser -home="/home/jdyer/.config/syncthing" &
autotiling &
udisksctl mount -b /dev/mmcblk0p1

# check for numpad plugged in and out
NUMPAD_CONNECTED=0
ONE_DISCONNECT=0

while :
do
   if [[ -L "/dev/input/by-id/usb-13ba_0001-event-kbd" ]]; then
      if [[ $NUMPAD_CONNECTED == 0 ]]; then
         kmonad ~/.config/kmonad/numpad.kbd &
         echo "NUMPAD CONNECTED!"
         notify-send -t 3000 "NUMPAD CONNECTED!"
         NUMPAD_CONNECTED=1
         case $DESKTOP_SESSION in
            sway)
               swaymsg input "$touch_wayland" events disabled
               ;;
            hyprland)
               hyprctl keyword "device:${touch_wayland}:enabled" true
               ;;
            plasma | i3)
               xinput disable "$touch_x11"
               ;;
            *)
               xinput disable "$touch_x11"
               ;;
         esac
         ONE_DISCONNECT=0
      fi
   else
      if [[ $ONE_DISCONNECT == 0 ]]; then
         echo "NUMPAD DISCONNECTED!"
         notify-send -t 3000 "NUMPAD DISCONNECTED!"
         NUMPAD_CONNECTED=0
         case $DESKTOP_SESSION in
            sway)
               # for sway disable touch screen
               swaymsg input "$touch_wayland" events enabled
               ;;
            hyprland)
               hyprctl keyword "device:${touch_wayland}:enabled" false
               ;;
            plasma | i3)
               xinput enable "$touch_x11"
               ;;
            *)
               xinput enable "$touch_x11"
               ;;
         esac
         ONE_DISCONNECT=1
      fi
   fi
   sleep 2
done
