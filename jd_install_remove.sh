#!/bin/bash

LIST=$(cat "/$HOME/bin/jd_install_remove.txt")

echo $LIST

for file in $LIST; do
   yay -R --noconfirm $file
done
