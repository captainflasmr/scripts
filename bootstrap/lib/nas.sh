#!/usr/bin/env bash
# nas.sh - shared NAS mount discovery + guard, sourced by the sync scripts.
#
# One home for the NAS coordinates (mount point, export path, known IPs) so
# sync-to-nas.sh / nas-pending-pull.sh can't drift. sync-from-nas.sh and
# startup_root.sh still carry their own copies; fold them in here when their
# current work-in-progress lands.
#
# Requires common.sh (info/section/die) to be sourced first.
# Environment overrides (used by tests / unusual setups):
#   NAS_MOUNT   default: $HOME/nas

NAS_MOUNT="${NAS_MOUNT:-$HOME/nas}"
NAS_HOME="$NAS_MOUNT/Home"                # the live mirror of $HOME on the NAS
NAS_REMOTE_PATH="/volume1/Drive"
# NAS moved to the Atria mesh subnet (192.168.7.x) after leaving the Virgin
# router. Old Virgin-router IPs kept as fallbacks in case it gets plugged back
# in. 192.168.0.21 is the DHCP lease startup_root.sh saw most recently.
NAS_TARGET_IPS=( "192.168.7.101" "192.168.0.21" "192.168.0.10" "192.168.0.11" "192.168.7.103" )

# True only when the NFS mount is real AND the Home/ mirror is visible — a
# stale empty ~/nas must not look mounted.
nas_mounted() { mountpoint -q "$NAS_MOUNT" && [[ -d $NAS_HOME ]]; }

# Mount the NAS if needed by trying each known IP once. Requires sudo (may
# prompt) — batch/unattended callers should use nas_mounted/wait_for_nas.
ensure_nas() {
    if nas_mounted; then
        info "NAS already mounted at $NAS_MOUNT"; return 0
    fi
    section "Mounting NAS"
    mkdir -p "$NAS_MOUNT"
    local ip
    for ip in "${NAS_TARGET_IPS[@]}"; do
        ping -c1 -W1 "$ip" &>/dev/null || continue
        info "trying $ip:$NAS_REMOTE_PATH"
        sudo mount -t nfs \
            -o nfsvers=3,rsize=1048576,wsize=1048576,noatime,actimeo=60 \
            "$ip:$NAS_REMOTE_PATH" "$NAS_MOUNT" &>/dev/null
        nas_mounted && { info "mounted via $ip"; return 0; }
    done
    return 1
}

# Poll for an already-mounted NAS without ever invoking sudo. SECONDS=0 does a
# single check; useful at login where the root mount loop may still be working.
wait_for_nas() {
    local end=$(( SECONDS + ${1:-0} ))
    while :; do
        nas_mounted && return 0
        (( SECONDS >= end )) && return 1
        sleep 3
    done
}
