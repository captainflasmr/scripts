#!/bin/bash
# backup all app list in Manjaro
DATE=$(date +%Y%m%d%H)
sudo pacman -Qeq > "$HOME/DCIM/Backup/$DATE"-packages.list
