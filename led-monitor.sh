#!/bin/bash

# Define the paths to the LED brightness indicators
caps_lock_led="/sys/class/leds/input2::capslock/brightness"
num_lock_led="/sys/class/leds/input2::numlock/brightness"
scroll_lock_led="/sys/class/leds/input2::scrolllock/brightness"

# Function to output the JSON format for Waybar
output_json() {
    local text="$1"
    local active="$2"
    if [ "$active" = "1" ]; then
        echo "{\"text\": \"$text\", \"class\": \"active\"}"
    else
        echo "{\"text\": \"$text\", \"class\": \"inactive\"}"
    fi
}

led_label="o"

# Check the command-line argument and output the respective LED status
case "$1" in
    --caps)
        caps_state=$(cat "$caps_lock_led")
        # output_json $led_label "$caps_state"
        output_json "Ctl" "$caps_state"
        ;;
    --num)
        num_state=$(cat "$num_lock_led")
        # output_json $led_label "$num_state"
        output_json "Alt" "$num_state"
        ;;
    --scroll)
        scroll_state=$(cat "$scroll_lock_led")
        # output_json $led_label "$scroll_state"
        output_json "Sft" "$scroll_state"
        ;;
    *)
        echo "Usage: $0 [--caps | --num | --scroll]"
        exit 1
        ;;
esac
