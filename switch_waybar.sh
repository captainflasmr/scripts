#!/bin/bash

# cd $HOME/.config

# if [ "$(readlink "waybar")" = "waybar_jdyer" ]; then
#     ln -sfn "waybar_garuda" "waybar"
#     echo "Switched to waybar_garuda."
# elif [ "$(readlink "waybar")" = "waybar_garuda" ]; then
#     ln -sfn "waybar_jdyer" "waybar"
#     echo "Switched to waybar_jdyer."
# else
#     echo "The symlink does not point to a known location."
# fi

# killall waybar
# waybar &

CONFIG_FILE="/home/jdyer/.config/WAYBAR"
CONFIG_GARUDA="/home/jdyer/.config/waybar_garuda"
CONFIG_JDYER="/home/jdyer/.config/waybar_jdyer"

if [[ ! -f $CONFIG_FILE ]]; then
   echo $CONFIG_GARUDA > $CONFIG_FILE
fi

CURRENT_CONFIG=$(cat $CONFIG_FILE)

if [[ $CURRENT_CONFIG == $CONFIG_GARUDA ]]; then
   NEW_CONFIG=$CONFIG_JDYER
else
   NEW_CONFIG=$CONFIG_GARUDA
fi

echo $NEW_CONFIG > $CONFIG_FILE

killall waybar

# Start waybar with the new configuration
waybar -c $NEW_CONFIG/config -s $NEW_CONFIG/style.css &

echo "Switched to $(basename $NEW_CONFIG)"
