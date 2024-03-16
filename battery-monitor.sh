#!/bin/bash
LOG_FILE="$HOME/battery_log.org"

trash-put "$LOG_FILE"

echo "#+NAME: battery-table" > "$LOG_FILE"
echo "#+PLOT: title:\"Battery\" ind:1 deps:(3) type:2d with:lines set:\"yrange [0:100]\"" >> "$LOG_FILE"
echo "|    | date                  | %  |" >> "$LOG_FILE"
echo "|----+-----------------------+----|" >> "$LOG_FILE"

counter=0

while true; do
   # Get battery percentage
   PERCENTAGE=$(upower -i /org/freedesktop/UPower/devices/battery_BAT1 \
            | grep percentage \
            | awk '{print $2}' \
            | tr -d '%')

   # Get current time
   TIME=$(date '+%Y-%m-%d %a %H:%M')

   # Log data
   echo "| $counter | <${TIME}> | $PERCENTAGE |" >> "$LOG_FILE"

   # Wait for a specified time interval in seconds
   sleep 300

   counter=$((counter + 1))
done
