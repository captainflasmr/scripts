#!/usr/bin/env bash
# setup-ventoy.sh - turn a blank USB stick into a single "everything" stick:
#   • Ventoy bootable partition (exFAT)  -> drop distro ISOs here
#   • small VTOYEFI partition            -> Ventoy's boot bits
#   • ext4 "INSTALL" partition           -> the bootstrap payload (run refresh-usb.sh into it)
#
# Usage:
#   ~/bin/bootstrap/setup-ventoy.sh /dev/sdX [--reserve-gib N] [--force] [--check]
#
# Defaults: reserve 100 GiB at the end of the disk for the ext4 payload partition,
# leaving the remainder as the Ventoy/ISO partition.
#
# THIS WIPES THE TARGET DEVICE. Safety guards:
#   - target must be given explicitly as a whole disk (e.g. /dev/sdb, not /dev/sdb1)
#   - target must be a USB / removable device (override with --force, at your own risk)
#   - target must not host any currently-mounted filesystem
#   - you must type the device name to confirm
#   - pass --check to probe the flash with f3probe for counterfeit/slow flash (opt-in)

set -uo pipefail
BOOTSTRAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$BOOTSTRAP_DIR/lib/common.sh"

RESERVE_GIB=100
FORCE=0
DO_CHECK=0
DEV=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --reserve-gib) RESERVE_GIB="$2"; shift 2 ;;
        --reserve-gib=*) RESERVE_GIB="${1#*=}"; shift ;;
        --force) FORCE=1; shift ;;
        --check) DO_CHECK=1; shift ;;
        -h|--help) sed -n '2,/^set /{/^set /d;p}' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        /dev/*) DEV="$1"; shift ;;
        *) die "unrecognised argument: $1" ;;
    esac
done
[[ $RESERVE_GIB =~ ^[0-9]+$ ]] || die "--reserve-gib must be a number (GiB)"

[[ -n $DEV ]] || die "usage: setup-ventoy.sh /dev/sdX [--reserve-gib N] [--force]"
[[ -b $DEV ]] || die "$DEV is not a block device"
[[ $DEV =~ [0-9]$ && $DEV != *nvme* && $DEV != *mmcblk* ]] && die "$DEV looks like a partition; give the whole disk (e.g. /dev/sdb)"

# locate Ventoy installer
VENTOY_SH=""
for p in /usr/share/ventoy/Ventoy2Disk.sh /opt/ventoy/Ventoy2Disk.sh; do
    [[ -x $p ]] && VENTOY_SH="$p" && break
done
[[ -n $VENTOY_SH ]] || die "Ventoy2Disk.sh not found. Install ventoy (pacman -S ventoy / ventoy-bin)."
require_cmd parted "Install parted."
require_cmd partprobe "Install parted."
require_cmd mkfs.ext4 "Install e2fsprogs."

# Ventoy 1.1.x formats its exFAT partition with the legacy 'mkexfatfs' tool.
# Modern Arch ships exfatprogs (mkfs.exfat) instead, which uses different flags.
# Install a tiny translating shim so Ventoy's call succeeds.
ensure_exfat_shim() {
    local shim=/usr/local/bin/mkexfatfs
    # If a *real* mkexfatfs (not our shim) is installed, trust it and stop.
    if command -v mkexfatfs &>/dev/null && [[ $(command -v mkexfatfs) != "$shim" ]]; then
        return 0
    fi
    command -v mkfs.exfat &>/dev/null || \
        die "No exFAT formatter found. Install exfatprogs (mkfs.exfat) or exfat-utils (mkexfatfs)."
    warn "Ventoy needs 'mkexfatfs'; only 'mkfs.exfat' (exfatprogs) is present."
    info "Installing/updating compatibility shim -> $shim"
    sudo tee "$shim" >/dev/null <<'SHIM'
#!/usr/bin/env bash
# Compatibility shim: legacy mkexfatfs args -> exfatprogs mkfs.exfat.
#   -n LABEL            -> -L LABEL
#   -s SECTORS_PER_CL   -> -c BYTES   (BYTES = SECTORS * 512)
# Wipe any leftover signature first, then -F to force (mkexfatfs always overwrote).
args=()
dev=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n) args+=(-L "$2"); shift 2 ;;
    -s) args+=(-c "$(( $2 * 512 ))"); shift 2 ;;
    /dev/*) dev="$1"; args+=("$1"); shift ;;
    *)  args+=("$1"); shift ;;
  esac
done
[[ -n $dev ]] && command -v wipefs &>/dev/null && wipefs -a "$dev" >/dev/null 2>&1 || true
exec mkfs.exfat -F "${args[@]}"
SHIM
    sudo chmod +x "$shim"
}

# Probe the stick for counterfeit / pathologically slow flash BEFORE we waste
# time partitioning and (later) hours rsyncing a backup onto dead flash.
# Opt-in (--check). Destructive, so it only runs after the wipe is confirmed.
preflight_stick_check() {
    [[ $DO_CHECK == 1 ]] || return 0
    if ! command -v f3probe &>/dev/null; then
        warn "f3probe not found — cannot verify the stick is genuine."
        warn "Strongly recommended: install it (pacman -S f3) and re-run."
        confirm "Continue WITHOUT verifying the stick?" || die "aborted — install f3 then retry"
        return 0
    fi
    section "Verifying flash with f3probe"
    warn "This destructively probes $DEV and can take several minutes"
    warn "(much longer on a failing device — that itself is a bad sign)."
    local out
    out=$(sudo f3probe --destructive --time-ops "$DEV" 2>&1)
    echo "$out"

    if grep -q "is a counterfeit" <<<"$out"; then
        err "$DEV is a COUNTERFEIT stick — its real capacity is less than advertised."
        die "refusing to use it for a backup"
    fi

    # sequential write-speed sanity: reject anything absurdly slow (< 1 MB/s)
    local line val unit mul bps
    line=$(grep -i 'Sequential write:' <<<"$out" | head -1)
    if [[ -n $line ]]; then
        val=$(sed -E 's/.*Sequential write:[[:space:]]*([0-9.]+).*/\1/' <<<"$line")
        unit=$(sed -E 's#.*Sequential write:[[:space:]]*[0-9.]+[[:space:]]*([KMGT]?B|Bytes)/s.*#\1#' <<<"$line")
        case "$unit" in
            Bytes|B) mul=1 ;;
            KB) mul=1000 ;;
            MB) mul=1000000 ;;
            GB) mul=1000000000 ;;
            *) mul=0 ;;
        esac
        if (( mul > 0 )); then
            bps=$(awk -v v="$val" -v m="$mul" 'BEGIN{printf "%.0f", v*m}')
            info "measured sequential write: ${val} ${unit}/s"
            if (( bps < 1000000 )); then
                err "Write speed ${val} ${unit}/s is far below usable (~1 MB/s) — stick is failing/junk."
                die "refusing to use it"
            fi
        fi
    fi
    grep -q "is the real thing" <<<"$out" && info "f3probe: stick is genuine ✓"
}

# --- safety: USB / removable check ----------------------------------------
base=$(basename "$DEV")
removable=$(cat "/sys/block/$base/removable" 2>/dev/null || echo 0)
tran=$(lsblk -dno TRAN "$DEV" 2>/dev/null)
if [[ $removable != 1 && $tran != usb ]]; then
    if [[ $FORCE == 1 ]]; then
        warn "$DEV is not flagged removable/USB — proceeding because --force was given"
    else
        die "$DEV is not a USB/removable device (tran=$tran removable=$removable). Refusing. Use --force to override."
    fi
fi

# --- safety: nothing mounted from this disk -------------------------------
if lsblk -nro MOUNTPOINT "$DEV" | grep -q .; then
    err "$DEV has mounted partitions:"; lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT "$DEV"
    die "Unmount everything on $DEV first."
fi

# --- show + confirm -------------------------------------------------------
section "Ventoy setup target"
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,TRAN "$DEV"
disk_gib=$(( $(lsblk -bdno SIZE "$DEV") / 1024 / 1024 / 1024 ))
iso_gib=$(( disk_gib - RESERVE_GIB ))
echo
info "total size:        ~${disk_gib} GiB"
info "Ventoy/ISO part:   ~${iso_gib} GiB (exFAT)"
info "INSTALL payload:   ~${RESERVE_GIB} GiB (ext4)"
(( iso_gib >= 4 )) || die "reserve too large: only ${iso_gib} GiB would be left for ISOs. Lower --reserve-gib."

echo
warn "This will ERASE ALL DATA on $DEV."
read -r -p "Type the device name ($DEV) to confirm: " typed
[[ $typed == "$DEV" ]] || die "confirmation did not match — aborting"

reserve_mb=$(( RESERVE_GIB * 1024 ))

# --- 0. verify the flash is genuine before doing any real work ------------
preflight_stick_check

# --- 1. Ventoy (interactive y/n from Ventoy2Disk.sh itself) ---------------
ensure_exfat_shim
section "Installing Ventoy (reserving ${RESERVE_GIB} GiB)"
sudo bash "$VENTOY_SH" -i -r "$reserve_mb" "$DEV" || die "Ventoy install failed"

# --- 2. ext4 partition in the reserved tail -------------------------------
section "Creating ext4 INSTALL partition"
sudo partprobe "$DEV"; sleep 1
ptype=$(sudo parted -ms "$DEV" print 2>/dev/null | awk -F: 'NR==2{print $6}')
info "partition table: ${ptype:-unknown}"
# locate the reserved tail: the LARGEST 'free' region parted reports
read -r tail_start tail_end < <(
    sudo parted -ms "$DEV" unit MiB print free | awk -F: '
        /free/ { s=$2; e=$3; sz=$4; gsub("MiB","",s); gsub("MiB","",e); gsub("MiB","",sz);
                 if (sz+0 > best) { best=sz+0; bs=s; be=e } }
        END { print bs, be }')
[[ -n $tail_start && -n $tail_end ]] || die "could not find reserved free space on $DEV"
info "reserved free region: ${tail_start}MiB .. ${tail_end}MiB"

# snapshot partitions, create the new one, then detect which one appeared
# (works for both GPT and MBR; MBR has no partition names so we can't query by name)
before=$(lsblk -nro NAME "$DEV" | tail -n +2 | sort)
# End at 100% (not the reported MiB value) so parted snaps to the true last
# aligned sector — the reported free-region end can round just past the device.
if [[ $ptype == gpt ]]; then
    sudo parted -s "$DEV" unit MiB mkpart INSTALL ext4 "${tail_start}" 100% || die "parted mkpart failed"
else
    sudo parted -s "$DEV" unit MiB mkpart primary ext4 "${tail_start}" 100% || die "parted mkpart failed"
fi
sudo partprobe "$DEV"; sleep 2
after=$(lsblk -nro NAME "$DEV" | tail -n +2 | sort)
newpart=$(comm -13 <(echo "$before") <(echo "$after") | grep -v '^$' | head -1)
[[ -n $newpart ]] || die "could not detect the newly created partition"
PART="/dev/$newpart"
info "new partition: $PART"
[[ -b $PART ]] || die "$PART did not appear"

# --- 3. format + take ownership -------------------------------------------
section "Formatting $PART as ext4 (label INSTALL)"
sudo mkfs.ext4 -F -L INSTALL "$PART" || die "mkfs.ext4 failed"
tmp=$(mktemp -d)
sudo mount "$PART" "$tmp" && sudo chown "$USER:$USER" "$tmp" && sudo umount "$tmp"
rmdir "$tmp"

section "Ventoy stick ready"
cat <<EOF
Next steps:
  1. Re-plug the stick (or let your file manager mount it). You'll get two volumes:
       Ventoy   -> copy distro .iso files here (Arch, Mint, …)
       INSTALL  -> the ext4 payload partition
  2. Populate the payload from this machine:
       ~/bin/bootstrap/refresh-usb.sh /run/media/$USER/INSTALL
  3. On a fresh laptop: boot the stick (Ventoy menu) -> install the OS ->
     reboot -> re-plug the stick -> cd /run/media/\$USER/INSTALL && ./install.sh
EOF
