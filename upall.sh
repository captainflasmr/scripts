#!/bin/bash
# my own update script
echo
echo "----------------------------------------"
echo "system update"
echo "----------------------------------------"
echo
sudo pacman -Syu
echo
echo "----------------------------------------"
echo "flatpak update"
echo "----------------------------------------"
echo
flatpak upgrade
