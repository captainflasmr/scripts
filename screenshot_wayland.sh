#!/bin/bash
# original command
# grim -t jpeg -g "$(slurp)" ~/DCIM/Screenshots/$(date +'%Y-%m-%d-%H-%M-%S.jpg')
# advent calendar ratio
# slurp -a 600:420 -d | grim -g - ~/DCIM/Screenshots/$(date +'%Y-%m-%d-%H-%M-%S.jpg')
slurp -d | grim -g - ~/DCIM/Screenshots/$(date +'%Y-%m-%d-%H-%M-%S.jpg')
