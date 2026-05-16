#!/bin/bash

# Configuration
MOUNT_POINT="/home/jdyer/nas"
REMOTE_PATH="/volume1/Drive"
# Re-ordered to put the working one first
TARGET_IPS=("192.168.0.10" "192.168.0.11" "192.168.7.103")
SCAN_RANGE=({100..110})
SUBNET="192.168.7"

echo "Starting NAS mount loop..."

while [[ ! -d "$MOUNT_POINT/Home" ]]; do
    # 1. Try the explicit list first
    for ip in "${TARGET_IPS[@]}"; do
        if ping -c 1 -W 1 "$ip" >/dev/null 2>&1; then
            echo "Attempting to mount via $ip..."
            
            # Removed -v and added &>/dev/null to swallow all errors/warnings
            mount -t nfs -o nfsvers=3 "$ip":"$REMOTE_PATH" "$MOUNT_POINT" &>/dev/null
            
            if [[ -d "$MOUNT_POINT/Home" ]]; then
                echo "Success! NAS is mounted."
                exit 0
            fi
        fi
    done

    # 2. Fallback: Scan range
    for i in "${SCAN_RANGE[@]}"; do
        ip="$SUBNET.$i"
        if ping -c 1 -W 1 "$ip" >/dev/null 2>&1; then
            mount -t nfs -o nfsvers=3 "$ip":"$REMOTE_PATH" "$MOUNT_POINT" &>/dev/null
            
            if [[ -d "$MOUNT_POINT/Home" ]]; then
                echo "Success! Mounted via discovered IP $ip"
                exit 0
            fi
        fi
    done

    echo "NAS not found. Retrying in 10 seconds..."
    sleep 10
done
