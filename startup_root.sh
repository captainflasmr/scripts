#!/bin/bash

# sleep 4

# ydotoold --socket-perm 0777 --socket-path=/run/user/1000/.ydotool_socket &

# cpupower frequency-set --governor powersave --max 1000MHz

xremap /home/jdyer/.config/xremap/emacs.yml &

while [[ ! -d /home/jdyer/nas/Home ]]; do
   # mount -t nfs captainflasmr:/volume1/Drive /home/jdyer/nas
   mount -v -t nfs 192.168.0.19:/volume1/Drive /home/jdyer/nas
   sleep 2
done
