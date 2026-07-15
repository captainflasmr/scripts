#!/usr/bin/env bash
# power-save.sh - Apply battery-saving tunables.
# Each block can be commented out individually.
set -uo pipefail

log() { echo "[power-save] $*"; }

stop_svc() { sudo systemctl stop "$1" 2>/dev/null || true; }
stop_usr() { systemctl --user stop "$1" 2>/dev/null || true; }

# --- 1. powertop tunables (USB autosuspend, PCI ASPM, SATA link power) ---
if command -v powertop &>/dev/null; then
    log "Applying powertop --auto-tune ..."
    sudo powertop --auto-tune 2>/dev/null
else
    log "powertop not installed; skipping"
fi

# --- 2. CPU energy performance preference ---
log "Setting EPP to power ..."
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
    echo 'power' | sudo tee "$cpu" &>/dev/null
done

# --- 3. i915 panel self-refresh + frame buffer compression ---
log "Enabling i915 PSR and FBC ..."
echo 1 | sudo tee /sys/module/i915/parameters/enable_psr &>/dev/null || true
echo 1 | sudo tee /sys/module/i915/parameters/enable_fbc &>/dev/null || true

# --- 4. Audio power save ---
log "Setting audio power_save=10 ..."
echo 10 | sudo tee /sys/module/snd_hda_intel/parameters/power_save &>/dev/null || true

# --- 5. Dirty writeback for laptop mode ---
log "Setting vm.dirty_writeback_centisecs=1500 ..."
sudo sysctl -w vm.dirty_writeback_centisecs=1500 &>/dev/null || true

# --- 7. Stop drainer services (comment out any you want to keep) ---

# User services
log "Stopping drainer user services ..."
stop_usr ollama.service             # LLM serving
stop_usr surfsharkd.service         # VPN
stop_usr kdeconnectd.service        # Phone integration

# System services
log "Stopping drainer system services ..."
stop_svc docker.service             # Container runtime
stop_svc containerd.service
stop_svc libvirtd.service           # VM host
stop_svc ModemManager.service       # Mobile broadband
stop_svc avahi-daemon.service       # mDNS

# --- 6. NMI watchdog (constant timer tick, saves a few % idle) ---
log "Disabling NMI watchdog ..."
echo 0 | sudo tee /proc/sys/kernel/nmi_watchdog &>/dev/null || true

log "Done"
