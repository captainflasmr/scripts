#!/bin/bash
maim --hidecursor --highlight --tolerance=0 --color=0.5,0.5,0.5,0.6 -s --noopengl --bordersize=3 ~/DCIM/Screenshots/$(date +%Y-%m-%d-%H-%M-%S_maim | tr A-Z a-z).jpg
