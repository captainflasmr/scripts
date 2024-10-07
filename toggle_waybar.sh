#!/bin/bash

# Waybar toggle script

# Determine if Waybar is running
if pgrep -x waybar > /dev/null; then
   # If Waybar is running, kill it
   killall waybar
else
   # If Waybar is not running, start it
   CONFIG_FILE="/home/jdyer/.config/WAYBAR"
   CONFIG_GARUDA="/home/jdyer/.config/waybar_garuda"
   CONFIG_JDYER="/home/jdyer/.config/waybar_jdyer"

   if [[ ! -f $CONFIG_FILE ]]; then
      echo $CONFIG_GARUDA > $CONFIG_FILE
   fi

   CURRENT_CONFIG=$(cat $CONFIG_FILE)

   # Start waybar with the new configuration
   waybar -c $CURRENT_CONFIG/config -s $CURRENT_CONFIG/style.css &
fi
