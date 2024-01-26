#!/bin/bash
# my own update script
echo
echo "----------------------------------------"
echo "system update"
echo "----------------------------------------"
echo
<<<<<<< Updated upstream
sudo pacman -Syu --noconfirm
=======
if command -v garuda-update &> /dev/null ; then
   echo "----------------------------------------"
   echo "garuda-update"
   echo "----------------------------------------"
   sudo garuda-update
else
   sudo pacman -Syu --noconfirm
fi
>>>>>>> Stashed changes
echo
echo "----------------------------------------"
echo "flatpak update"
echo "----------------------------------------"
echo
flatpak upgrade
