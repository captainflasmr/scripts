#!/bin/bash

function set_led_paths {
    local keyboard_id="$1"
    # Define the LED paths based on the passed keyboard ID
    caps_lock_led="/sys/class/leds/input${keyboard_id}::capslock/brightness"
    num_lock_led="/sys/class/leds/input${keyboard_id}::numlock/brightness"
    scroll_lock_led="/sys/class/leds/input${keyboard_id}::scrolllock/brightness"
}

function check_led_paths_exist {
    # Check if all the necessary LED files exist
    [[ -f "$caps_lock_led" && -f "$num_lock_led" && -f "$scroll_lock_led" ]]
}

function get_keyboard_id {
    local device_name="$1"
    local device_sysfs_entry=$(awk -v RS='' "/Name=$device_name/" /proc/bus/input/devices | grep Sysfs | awk '{print $2}')
    local input_identifier=$(echo $device_sysfs_entry | sed 's/.*input\([^/]*\).*/\1/')
    echo "$input_identifier"
}

function output_json {
    local text="$1"
    local active="$2"
    if [ "$active" = "1" ]; then
       # echo "{\"text\": \"$text\", \"class\": \"active\"}"
       echo "{\"text\": \"🔴\", \"class\": \"active\"}"
    else
       # echo "{\"text\": \"$text\", \"class\": \"inactive\"}"
       echo "{\"text\": \"o\", \"class\": \"inactive\"}"
    fi
}

# Declare an array of keyboard names in priority order
keyboard_names=("SEMICO   USB Gaming Keyboard " "AT Translated Set 2 keyboard" "Another Keyboard Model")

# Iterate through the keyboards and try setting the LED paths
keyboard_found=0
for name in "${keyboard_names[@]}"; do
    keyboard_id=$(get_keyboard_id "\"$name\"")
    set_led_paths "$keyboard_id"
    if check_led_paths_exist; then
        keyboard_found=1
        break
    fi
done

if [ "$keyboard_found" -eq 0 ]; then
    echo "No suitable keyboard found."
    exit 1
fi

# Check command-line argument and output the respective LED status
case "$1" in
    --caps)
        caps_state=$(cat "$caps_lock_led" 2>/dev/null || echo "0")
        output_json "🖲️" "$caps_state"
        ;;
    --num)
        num_state=$(cat "$num_lock_led" 2>/dev/null || echo "0")
        output_json "🖲️" "$num_state"
        ;;
    --scroll)
        scroll_state=$(cat "$scroll_lock_led" 2>/dev/null || echo "0")
        output_json "🖲️" "$scroll_state"
        ;;
    *)
        echo "Usage: $0 [--caps | --num | --scroll]"
        exit 1
        ;;
esac
