#!/bin/bash

# The cron job you want to add
CRON_JOB="@reboot /home/jdyer/bin/startup_root.sh"

# Check if the cron job already exists
if ! sudo crontab -l | grep -Fxq "$CRON_JOB"; then
    (sudo crontab -l; echo "$CRON_JOB") | sudo crontab -
    echo "Cron job added successfully."
else
    echo "Cron job already exists. No action taken."
fi
