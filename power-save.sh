#!/usr/bin/env bash
# power-save.sh - Apply battery-saving tunables.
# Each block can be commented out individually.
set -uo pipefail

log() { echo "[power-save] $*"; }

stop_svc() { sudo systemctl stop "$1" 2>/dev/null || true; }
stop_usr() { systemctl --user stop "$1" 2>/dev/null || true; }

# Kill matching processes by name with SIGKILL.
# Useful when systemd stop leaves orphaned processes (e.g. ollama).
kill_procs() {
    for name in "$@"; do
        if command -v killall &>/dev/null; then
            sudo killall -9 "$name" 2>/dev/null || true
        else
            pkill -9 -x "$name" 2>/dev/null || true
        fi
    done
}

# --- 1. powertop tunables (USB autosuspend, PCI ASPM, SATA link power) ---
if command -v powertop &>/dev/null; then
    log "Applying powertop --auto-tune ..."
    sudo powertop --auto-tune 2>/dev/null
else
    log "powertop not installed; skipping"
fi

# --- 2. SATA link power management (ALPM) ---
log "Setting SATA ALPM to med_power_with_dipm ..."
for policy in /sys/class/scsi_host/host*/link_power_management_policy; do
    [ -f "$policy" ] && echo 'med_power_with_dipm' | sudo tee "$policy" &>/dev/null
done

# --- 3. Wi-Fi power saving ---
if command -v iw &>/dev/null; then
    log "Enabling Wi-Fi power saving..."
    for interface in /sys/class/net/w*; do
        if [ -d "$interface" ]; then
            sudo iw dev "${interface##*/}" set power_save on &>/dev/null || true
        fi
    done
fi

# --- 4. CPU scaling governor + energy performance preference ---
log "Setting scaling governor to powersave ..."
for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    [ -f "$gov" ] && echo 'powersave' | sudo tee "$gov" &>/dev/null
done
log "Setting EPP to power ..."
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
    [ -f "$cpu" ] && echo 'power' | sudo tee "$cpu" &>/dev/null
done

# --- 5. i915 panel self-refresh + frame buffer compression ---
# NOTE: These are read-only at runtime on most kernels. Set them at boot via
#       /etc/modprobe.d/i915.conf (see that file). The writes below are best-effort.
log "Enabling i915 PSR and FBC ..."
echo 1 | sudo tee /sys/module/i915/parameters/enable_psr &>/dev/null || true
echo 1 | sudo tee /sys/module/i915/parameters/enable_fbc &>/dev/null || true

# --- 6. Audio power save ---
log "Setting audio power_save=10 and power_save_controller=Y ..."
echo 10 | sudo tee /sys/module/snd_hda_intel/parameters/power_save &>/dev/null || true
echo 'Y' | sudo tee /sys/module/snd_hda_intel/parameters/power_save_controller &>/dev/null || true

# --- 7. Dirty writeback for laptop mode ---
log "Setting vm.dirty_writeback_centisecs=1500 ..."
sudo sysctl -w vm.dirty_writeback_centisecs=1500 &>/dev/null || true

# --- 9. Stop drainer services (comment out any you want to keep) ---

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

# --- 10. Aggressive process kill (systemd stop can orphan processes) ---
# Uncomment lines below for processes that survive systemctl stop.
log "Killing leftover drainer processes with SIGKILL ..."
kill_procs ollama                    # orphaned ollama serve
kill_procs surfshark               # VPN daemon leftovers
kill_procs docker                  # orphaned container processes
kill_procs qemu-system-x86_64      # lingering VMs

# --- 8. NMI watchdog (constant timer tick, saves a few % idle) ---
log "Disabling NMI watchdog ..."
echo 0 | sudo tee /proc/sys/kernel/nmi_watchdog &>/dev/null || true

log "Done"
