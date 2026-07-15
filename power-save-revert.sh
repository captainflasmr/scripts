#!/usr/bin/env bash
# power-save-revert.sh - Reverse power-save.sh settings back to defaults.
# Each block can be commented out individually.
set -uo pipefail

log() { echo "[power-save-revert] $*"; }

start_svc() { sudo systemctl start "$1" 2>/dev/null || true; }
start_usr() { systemctl --user start "$1" 2>/dev/null || true; }

# Re-kill matching processes (cleanup in case they auto-respawned).
# Mirrors kill_procs in power-save.sh.
kill_procs() {
    for name in "$@"; do
        if command -v killall &>/dev/null; then
            sudo killall -9 "$name" 2>/dev/null || true
        else
            pkill -9 -x "$name" 2>/dev/null || true
        fi
    done
}

# --- 1. powertop -> no revert needed (tunables are ephemeral, reboot resets) ---

# --- 2. SATA ALPM back to max_performance ---
log "Resetting SATA ALPM to max_performance ..."
for policy in /sys/class/scsi_host/host*/link_power_management_policy; do
    [ -f "$policy" ] && echo 'max_performance' | sudo tee "$policy" &>/dev/null
done

# --- 3. Wi-Fi power saving off ---
if command -v iw &>/dev/null; then
    log "Disabling Wi-Fi power saving..."
    for interface in /sys/class/net/w*; do
        if [ -d "$interface" ]; then
            sudo iw dev "${interface##*/}" set power_save off &>/dev/null || true
        fi
    done
fi

# --- 4. Scaling governor back to performance ---
log "Setting scaling governor to performance ..."
for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    [ -f "$gov" ] && echo 'performance' | sudo tee "$gov" &>/dev/null
done

# --- 5. EPP back to balance_performance ---
log "Setting EPP to balance_performance ..."
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
    [ -f "$cpu" ] && echo 'balance_performance' | sudo tee "$cpu" &>/dev/null
done

# --- 6. i915 PSR and FBC off ---
log "Disabling i915 PSR and FBC ..."
echo 0 | sudo tee /sys/module/i915/parameters/enable_psr &>/dev/null || true
echo 0 | sudo tee /sys/module/i915/parameters/enable_fbc &>/dev/null || true

# --- 7. Audio power save off ---
log "Disabling audio power_save ..."
echo 0 | sudo tee /sys/module/snd_hda_intel/parameters/power_save &>/dev/null || true
echo 'N' | sudo tee /sys/module/snd_hda_intel/parameters/power_save_controller &>/dev/null || true

# --- 8. Dirty writeback default ---
log "Resetting vm.dirty_writeback_centisecs to 500 ..."
sudo sysctl -w vm.dirty_writeback_centisecs=500 &>/dev/null || true

# --- 9. NMI watchdog on ---
log "Enabling NMI watchdog ..."
echo 1 | sudo tee /proc/sys/kernel/nmi_watchdog &>/dev/null || true

# --- 10. Kill leftovers before restarting (ensures clean start) ---
log "Killing leftover drainer processes before restart ..."
kill_procs ollama
# kill_procs surfshark
# kill_procs docker
# kill_procs qemu-system-x86_64

# --- 11. Restart drainer services ---

# User services
log "Starting drainer user services ..."
start_usr ollama.service
start_usr surfsharkd.service
start_usr kdeconnectd.service

# System services
log "Starting drainer system services ..."
start_svc docker.service
start_svc containerd.service
start_svc libvirtd.service
start_svc ModemManager.service
start_svc avahi-daemon.service

log "Done"
