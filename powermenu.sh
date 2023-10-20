#!/bin/bash
option1="  lock"
option2="  logout"
option3="  reboot"
option4="  power off"

options="$option1\n$option2\n$option3\n$option4"

choice=$(echo -e "$options" | rofi -dmenu -i -no-show-icons -l 4 -width 30 -p "Powermenu")

case $choice in
   $option1)
      swaylock -f -c 000000
      ;;
   $option2)
      case $DESKTOP_SESSION in
         sway)
            swaynag -t warning -m 'You pressed the exit shortcut. Do you really want to exit sway? This will end your Wayland session.' -B 'Yes, exit sway' 'swaymsg exit'
            ;;
         hyprland)
            hyprctl dispatch exit
            ;;
      esac
      ;;
   $option3)
      systemctl reboot ;;
   $option4)
      systemctl poweroff ;;
esac
