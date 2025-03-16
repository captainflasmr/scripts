#!/bin/bash
# the script to install all my stuff after a basic arch / sway type of
# install.  The location will have to be where the Home folder resides
# on the external driver

CUR_DIR=$PWD
BIN_DIR=$CUR_DIR/Home/bin

echo
echo "----------------------------------------"
echo "installing cron"
echo "----------------------------------------"
echo
CRON_JOB="@reboot /home/jdyer/bin/startup_root.sh"
if ! sudo crontab -l | grep -Fxq "$CRON_JOB"; then
    (sudo crontab -l; echo "$CRON_JOB") | sudo crontab -
    echo "Cron job added successfully."
else
    echo "Cron job already exists. No action taken."
fi
