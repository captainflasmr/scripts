#!/bin/bash

# sleep 4

# ydotoold --socket-perm 0777 --socket-path=/run/user/1000/.ydotool_socket &

while [[ ! -d /home/jdyer/nas/Home ]]; do
   # mount -t nfs captainflasmr:/volume1/Drive /home/jdyer/nas
   mount -v -t nfs 192.168.1.198:/volume1/Drive /home/jdyer/nas
   sleep 2
done
