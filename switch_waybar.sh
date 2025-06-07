#!/bin/bash

# List your waybar configs here (add/remove as needed)
CONFIG_DIR="$HOME/.config"
CONFIGS=(
    "$CONFIG_DIR/waybar_garuda"
    "$CONFIG_DIR/waybar_jdyer"
    "$CONFIG_DIR/waybar_custom"   # Add your third config here
)

CONFIG_FILE="$CONFIG_DIR/WAYBAR"   # Stores the current config path

# Initialize CONFIG_FILE if it doesn't exist
if [[ ! -f $CONFIG_FILE ]]; then
    echo "${CONFIGS[0]}" > "$CONFIG_FILE"
fi

CURRENT_CONFIG=$(cat "$CONFIG_FILE")

# Find current index in array
CURRENT_INDEX=-1
for i in "${!CONFIGS[@]}"; do
    if [[ "${CONFIGS[$i]}" == "$CURRENT_CONFIG" ]]; then
        CURRENT_INDEX=$i
        break
    fi
done

# If not found, default to the first config
if [[ $CURRENT_INDEX -eq -1 ]]; then
    CURRENT_INDEX=0
fi

# Compute next config index (cycle)
NEXT_INDEX=$(( (CURRENT_INDEX + 1) % ${#CONFIGS[@]} ))
NEW_CONFIG="${CONFIGS[$NEXT_INDEX]}"
echo "$NEW_CONFIG" > "$CONFIG_FILE"

# Kill and restart waybar with new config
killall waybar 2>/dev/null
waybar -c "$NEW_CONFIG/config" -s "$NEW_CONFIG/style.css" &

echo "Switched to $(basename "$NEW_CONFIG")"
