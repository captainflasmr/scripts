#!/bin/bash
#/bin/bash /home/jdyer/scripts/TO912.sh
# xinput disable 'ATML1000:00 03EB:2150'

# xinput list
# ⎡ Virtual core pointer                    	id=2	[master pointer  (3)]
# ⎜   ↳ Virtual core XTEST pointer              	id=4	[slave  pointer  (2)]
# ⎜   ↳ ZNT0001:00 14E5:E545 Mouse              	id=10	[slave  pointer  (2)]
# ⎜   ↳ ZNT0001:00 14E5:E545 Touchpad           	id=11	[slave  pointer  (2)]
# ⎜   ↳ Keymapper                               	id=20	[slave  pointer  (2)]
# ⎜   ↳ ATML1000:00 03EB:2150                   	id=14	[slave  pointer  (2)]

#  % xinput list-props 11 | grep -i scrol
# 	libinput Natural Scrolling Enabled (306):	1
# 	libinput Natural Scrolling Enabled Default (307):	0
# 	libinput Scroll Methods Available (308):	1, 1, 0
# 	libinput Scroll Method Enabled (309):	1, 0, 0
# 	libinput Scroll Method Enabled Default (310):	1, 0, 0
# 	libinput Accel Custom Scroll Points (324):	<no items>
# 	libinput Accel Custom Scroll Step (325):	0.000000
# 	libinput Horizontal Scroll Enabled (329):	1
# 	libinput Scrolling Pixel Distance (330):	30
# 	libinput Scrolling Pixel Distance Default (331):	15
# 	libinput High Resolution Wheel Scroll Enabled (332):	1

# emacs --bg-daemon

# xinput set-prop 'ZNT0001:00 14E5:E545 Touchpad' 'libinput Scrolling Pixel Distance' 50

sleep 1

xinput set-prop "ZNT0001:00 14E5:E545 Touchpad" "libinput Natural Scrolling Enabled" 1
xinput set-prop "ZNT0001:00 14E5:E545 Touchpad" "libinput Accel Speed" 0.8

sleep 1

if [[ $XDG_SESSION_TYPE == "x11" ]]; then
   if ! pgrep "^sxhkd$" >/dev/null; then
      /usr/bin/sxhkd &
   fi
   touch_disable.sh
fi

if ! pgrep "^kmonad$" >/dev/null; then
   kmonad ~/.config/kmonad/keyboard.kbd &
   kmonad ~/.config/kmonad/numpad.kbd &
fi

if ! pgrep "^syncthing$" >/dev/null; then
   /usr/bin/syncthing -no-browser -no-browser -home="/home/jdyer/.config/syncthing" &
fi

if ! pgrep "^fusuma$" >/dev/null; then
   /usr/bin/fusuma -d
fi

# if ! pgrep "^keymapper$" >/dev/null; then
#    keymapper -u &
# fi

if ! pgrep "^dunst$" >/dev/null; then
   dunst &
fi

if ! pgrep "^autotiling$" >/dev/null; then
   autotiling &
fi
