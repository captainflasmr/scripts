#!/bin/bash
LOG_FILE="$HOME/battery_log.org"

BATTERY=$(upower -e | grep battery | head -1)

# Determine the last logged day to resume correctly
last_day=""
if [[ -f "$LOG_FILE" ]]; then
    last_day=$(grep -oP '#\+NAME: battery-table-\K\d{4}-\d{2}-\d{2}' "$LOG_FILE" | tail -1)
fi

current_day=$(date '+%Y-%m-%d')

# Start a new table if file is missing or day has changed
if [[ ! -f "$LOG_FILE" ]] || [[ "$current_day" != "$last_day" ]]; then
    echo "" >> "$LOG_FILE"
    echo "#+NAME: battery-table-$current_day" >> "$LOG_FILE"
    echo "#+PLOT: title:\"Battery $current_day\" ind:1 deps:(3) type:2d with:lines set:\"yrange [0:100]\"" >> "$LOG_FILE"
    echo "|    | date                  | %  |" >> "$LOG_FILE"
    echo "|----+-----------------------+----|" >> "$LOG_FILE"
fi

# Determine starting counter from last row of current day's table
counter=$(tail -1 "$LOG_FILE" | grep -oP '^\|\s*\K\d+' | head -1)
counter=${counter:--1}
counter=$((counter + 1))

while true; do
   current_day=$(date '+%Y-%m-%d')

   # Check if day changed mid-loop
   last_day=$(grep -oP '#\+NAME: battery-table-\K\d{4}-\d{2}-\d{2}' "$LOG_FILE" | tail -1)
   if [[ "$current_day" != "$last_day" ]]; then
       echo "" >> "$LOG_FILE"
       echo "#+NAME: battery-table-$current_day" >> "$LOG_FILE"
       echo "#+PLOT: title:\"Battery $current_day\" ind:1 deps:(3) type:2d with:lines set:\"yrange [0:100]\"" >> "$LOG_FILE"
       echo "|    | date                  | %  |" >> "$LOG_FILE"
       echo "|----+-----------------------+----|" >> "$LOG_FILE"
       counter=0
   fi

   # Get battery percentage
   PERCENTAGE=$(upower -i "$BATTERY" \
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
