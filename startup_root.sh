#!/bin/bash

while [[ ! -d /home/jdyer/nas/Home ]]; do
   mount -v -t nfs 192.168.0.19:/volume1/Drive /home/jdyer/nas
   sleep 2
done
