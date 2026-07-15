#!/usr/bin/env bash
# power-save-revert.sh - Reverse power-save.sh settings back to defaults.
# Each block can be commented out individually.
set -uo pipefail

log() { echo "[power-save-revert] $*"; }

start_svc() { sudo systemctl start "$1" 2>/dev/null || true; }
start_usr() { systemctl --user start "$1" 2>/dev/null || true; }

# --- 1. powertop -> no revert needed (tunables are ephemeral, reboot resets) ---

# --- 2. EPP back to balance_performance ---
log "Setting EPP to balance_performance ..."
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
    echo 'balance_performance' | sudo tee "$cpu" &>/dev/null
done

# --- 3. i915 PSR and FBC off ---
log "Disabling i915 PSR and FBC ..."
echo 0 | sudo tee /sys/module/i915/parameters/enable_psr &>/dev/null || true
echo 0 | sudo tee /sys/module/i915/parameters/enable_fbc &>/dev/null || true

# --- 4. Audio power save off ---
log "Disabling audio power_save ..."
echo 0 | sudo tee /sys/module/snd_hda_intel/parameters/power_save &>/dev/null || true

# --- 5. Dirty writeback default ---
log "Resetting vm.dirty_writeback_centisecs to 500 ..."
sudo sysctl -w vm.dirty_writeback_centisecs=500 &>/dev/null || true

# --- 6. NMI watchdog on ---
log "Enabling NMI watchdog ..."
echo 1 | sudo tee /proc/sys/kernel/nmi_watchdog &>/dev/null || true

# --- 7. Restart drainer services ---

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
