#!/bin/bash

cd $HOME/.config

if [ "$(readlink "waybar")" = "waybar_jdyer" ]; then
    ln -sfn "waybar_garuda" "waybar"
    echo "Switched to waybar_garuda."
elif [ "$(readlink "waybar")" = "waybar_garuda" ]; then
    ln -sfn "waybar_jdyer" "waybar"
    echo "Switched to waybar_jdyer."
else
    echo "The symlink does not point to a known location."
fi

killall waybar
waybar &
