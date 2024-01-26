#!/bin/bash

#pip install --upgrade youtube-dl
#sudo pip install -U youtube-dl

# Just download a simple video
yt-dlp --format mp4 -o '%(title)s.%(ext)s' -v "$1"
