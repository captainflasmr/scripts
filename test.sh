#!/bin/bash
echo "poop: 4"
# setKeyboardLight () {
    dbus-send --system --type=method_call --dest="org.freedesktop.UPower" "/org/freedesktop/UPower/KbdBacklight" "org.freedesktop.UPower.KbdBacklight.SetBrightness" int32:0
echo "poop: 3"
# }

# setKeyboardLight 0

# if pgrep "^wf-recorder$" >/dev/null; then echo '{"class": "recording"}'; fi

# if pgrep "^wf-recorder$" >/dev/null; then
#    echo '{\"class\": \"recording\"}'
# else
#    echo '{\"class\": \"ready\"}'
# fi

# if pgrep "^wf-recorder$" >/dev/null; then
#    echo '{\"class\": \"recording\"}'
# fi

# if pgrep "^wf-recorder$" >/dev/null; then
#    echo "poop: 1"
# else
#    echo "poop: 2"
# fi

   # if [[ ! $XDG_CURRENT_DESKTOP == "KDE" ]]; then
#    echo "poop: 1"
# fi
