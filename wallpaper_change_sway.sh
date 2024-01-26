#!/bin/bash
swww img $(find ~/wallpaper -type f | shuf -n 1) --transition-step 20 --transition-fps=20
