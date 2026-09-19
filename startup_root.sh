#!/bin/bash

# Configuration
MOUNT_POINT="/home/jdyer/nas"
REMOTE_PATH="/volume1/Drive"
# NAS normally lives on the Atria mesh subnet (192.168.7.x). After a power
# cycle it can come back on the old 192.168.0.x network (DHCP lease from the
# old router), so known addresses on BOTH subnets are tried, then both /24s
# are swept until it answers.
TARGET_IPS=("192.168.7.101" "192.168.0.21" "192.168.0.10" "192.168.0.11" "192.168.7.103")
SUBNETS=("192.168.7" "192.168.0")
LOG="/var/log/nas-mount.log"

log() { echo "$(date '+%F %T') $*" >> "$LOG"; }

# Ensure the mount point exists — a fresh install won't have ~/nas yet, and NFS
# can't mount onto a missing directory. (Runs as root from cron; hand it back to
# the user so they can use ~/nas even while the NAS is unmounted.)
mkdir -p "$MOUNT_POINT"
chown jdyer "$MOUNT_POINT" 2>/dev/null || true

echo "Starting NAS mount loop..."
log "NAS mount loop starting"

# NFS-over-TCP defaults to just 2 outstanding RPCs per connection
# (sunrpc.tcp_slot_table_entries=2). On a WiFi/mesh path (~4ms RTT) that caps
# both bulk throughput and metadata concurrency. Raise it before mounting so
# every new transport picks it up. Persistent copy lives in
# /etc/sysctl.d/90-nfs-slots.conf.
modprobe sunrpc 2>/dev/null || true
if [[ -w /proc/sys/sunrpc/tcp_slot_table_entries ]]; then
    echo 128 > /proc/sys/sunrpc/tcp_slot_table_entries
    log "set sunrpc.tcp_slot_table_entries=128"
fi

while [[ ! -d "$MOUNT_POINT/Home" ]]; do
    # Only hosts that actually speak NFS are worth mounting: a device that
    # merely answers ping (printers, phones, other PCs) would otherwise make
    # mount.nfs block for minutes on its portmapper before timing out.
    nfs_ports_open () {
        local ip="$1"
        timeout 1 bash -c "echo >/dev/tcp/$ip/2049" 2>/dev/null && return 0
        timeout 1 bash -c "echo >/dev/tcp/$ip/111"  2>/dev/null && return 0
        return 1
    }

    # Try to mount; success is verified by ~/nas/Home appearing. The mount is
    # bounded with timeout so a flaky/filtering host can't stall the loop.
    # rsize/wsize=1M: fewer RPCs per byte (client/server negotiate down if the
    # NAS can't do 1M). noatime: no atime write traffic on the backup target.
    # actimeo=60: stretch attribute caching to cut revalidation traffic.
    try_mount () {
        local ip="$1"
        nfs_ports_open "$ip" || { log "skip $ip (no NFS ports)"; return 1; }
        echo "Attempting to mount via $ip..."
        timeout 15 mount -t nfs \
            -o nfsvers=3,rsize=1048576,wsize=1048576,noatime,actimeo=60 \
            "$ip:$REMOTE_PATH" "$MOUNT_POINT" &>/dev/null
        if [[ -d "$MOUNT_POINT/Home" ]]; then
            echo "Success! NAS is mounted via $ip"
            log "SUCCESS: mounted via $ip"
            exit 0
        fi
        log "mount failed: $ip"
    }

    # 1. Try the explicit list first (known addresses on both subnets)
    for ip in "${TARGET_IPS[@]}"; do
        if ping -c 1 -W 1 "$ip" >/dev/null 2>&1; then
            try_mount "$ip"
        fi
    done

    # 2. Fallback: sweep both subnets in parallel, try every responder
    echo "Explicit list failed; sweeping subnets..."
    log "explicit list failed; sweeping subnets"
    for SUBNET in "${SUBNETS[@]}"; do
        SWEEP="/tmp/nas-sweep-$$.txt"
        seq 1 254 | xargs -P 64 -I{} sh -c \
            'ping -c 1 -W 1 '"$SUBNET"'.{} >/dev/null 2>&1 && echo '"$SUBNET"'.{}' \
            | sort -t. -k4 -n > "$SWEEP"
        while IFS= read -r ip; do
            try_mount "$ip"
        done < "$SWEEP"
        rm -f "$SWEEP"
    done

    echo "NAS not found. Retrying in 10 seconds..."
    log "NAS not found; retrying in 10 seconds"
    sleep 10
done