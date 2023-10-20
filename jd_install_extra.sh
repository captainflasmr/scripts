#!/bin/bash

LIST=$(cat "/$HOME/bin/jd_install_extra.txt")

echo $LIST

# pacman and AUR
for file in $LIST; do
   # SUSE
   #sudo zypper install -y $file
   # Arch
   yay -Sy --noconfirm --needed $file
done
