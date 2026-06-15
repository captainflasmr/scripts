#!/usr/bin/env bash
# steps.sh - discrete, idempotent install steps. Sourced after common.sh+pkg.sh.
# Each step is safe to re-run. SRC_DIR points at the USB payload root.

# --- restore home (dotfiles + bin + plain dotfiles) -----------------------
# Mirrors $SRC_DIR/home/ into $HOME, excluding caches and anything that should
# never be blindly overwritten. Secrets and bulk data are handled separately.
step_restore_home() {
    section "Restoring home (dotfiles, bin, config)"
    [[ -d $SRC_DIR/home ]] || { warn "no home/ payload on stick, skipping"; return 0; }
    rsync -rlptP --human-readable \
        --exclude '.cache/' \
        --exclude '.local/share/Trash/' \
        --exclude '.gnupg/' --exclude '.ssh/' \
        --exclude '.authinfo' --exclude '.authinfo.gpg' \
        "$SRC_DIR/home/" "$HOME/"
}

# --- restore secrets (gpg symmetric archive) ------------------------------
step_restore_secrets() {
    section "Restoring secrets (.ssh / .gnupg / .authinfo)"
    local enc="$SRC_DIR/secrets.tar.gz.gpg"
    [[ -f $enc ]] || { warn "no secrets archive on stick, skipping"; return 0; }
    require_cmd gpg "Install gnupg first."
    # Read the passphrase and decrypt via loopback (no agent/pinentry needed —
    # a fresh minimal install often has no GUI pinentry running).
    local _pp; read -rs -p "Passphrase for secrets archive: " _pp; echo
    if gpg --batch --pinentry-mode loopback --passphrase-fd 3 --decrypt "$enc" 3<<<"$_pp" \
        | tar -xz -C "$HOME"; then
        unset _pp
    else
        unset _pp; die "secrets decryption/extract failed (wrong passphrase?)"
    fi
    # lock down permissions
    [[ -d $HOME/.gnupg ]] && { find "$HOME/.gnupg" -type d -exec chmod 700 {} \; ; find "$HOME/.gnupg" -type f -exec chmod 600 {} \; ; }
    [[ -d $HOME/.ssh ]]   && { find "$HOME/.ssh"   -type d -exec chmod 700 {} \; ; find "$HOME/.ssh"   -type f -exec chmod 600 {} \; ; }
    info "secrets restored and permissions tightened"
}

# --- bulk data (DCIM / source / wallpaper) --------------------------------
step_restore_data() {
    section "Restoring bulk data"
    [[ -d $SRC_DIR/data ]] || { warn "no data/ payload on stick, skipping"; return 0; }
    local d
    for d in "$SRC_DIR"/data/*/; do
        [[ -d $d ]] || continue
        local name; name=$(basename "$d")
        info "rsync $name -> ~/$name"
        rsync -rlptP --human-readable "$d" "$HOME/$name/"
    done
}

# --- default shell -> fish ------------------------------------------------
step_set_shell() {
    section "Default shell"
    command -v fish &>/dev/null || { warn "fish not installed, skipping shell change"; return 0; }
    local current; current=$(getent passwd "$USER" | cut -d: -f7)
    if [[ $current == "$(command -v fish)" ]]; then
        info "fish already the default shell"
    else
        info "switching default shell to fish"
        chsh -s "$(command -v fish)" || warn "chsh failed (set manually later)"
    fi
}

# --- user groups ----------------------------------------------------------
step_groups() {
    section "User groups"
    local g
    for g in input audio video; do
        if groups "$USER" | tr ' ' '\n' | grep -qx "$g"; then
            info "already in group: $g"
        else
            info "adding $USER to group: $g"; sudo usermod -aG "$g" "$USER" || warn "usermod $g failed"
        fi
    done
}

# --- cron + NAS auto-mount on reboot --------------------------------------
# Optional: only useful on machines that live on your LAN with the NAS.
step_cron_nasmount() {
    section "Cron / NAS auto-mount"
    case "$DISTRO" in
        arch) sudo pacman -S --needed --noconfirm cronie >/dev/null 2>&1
              sudo systemctl enable --now cronie ;;
        mint) sudo apt-get install -y cron >/dev/null 2>&1
              sudo systemctl enable --now cron ;;
    esac
    local job="@reboot $HOME/bin/startup_root.sh"
    if sudo crontab -l 2>/dev/null | grep -Fxq "$job"; then
        info "reboot NAS-mount cron already present"
    else
        ( sudo crontab -l 2>/dev/null; echo "$job" ) | sudo crontab -
        info "added reboot NAS-mount cron"
    fi
}

# --- disable display manager (greetd / sddm / gdm / lightdm) -------------
step_disable_display_manager() {
    section "Display manager"
    local dm
    for dm in greetd sddm gdm lightdm lxdm; do
        if systemctl cat "$dm.service" &>/dev/null; then
            info "disabling and masking $dm"
            sudo systemctl disable --now "$dm" 2>/dev/null || true
            sudo systemctl mask "$dm"
            return 0
        fi
    done
    info "no display manager service found — nothing to disable"
}

# --- distro / hardware quirks --------------------------------------------
# Samsung laptops: brightness keys need a kernel param. Opt-in, since it
# rewrites GRUB config.
step_quirk_samsung_backlight() {
    confirm "Apply Samsung Galaxy Book i915 backlight fix?" || { info "skipped"; return 0; }
    local grub=/etc/default/grub
    [[ -f $grub ]] || { warn "$grub not found"; return 0; }
    local changed=0
    for param in "acpi_backlight=native" "i915.enable_dpcd_backlight=3"; do
        if grep -q "$param" "$grub"; then
            info "already present: $param"
        else
            sudo sed -i -E "s/(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*)/\1 $param/" "$grub"
            info "added: $param"
            changed=1
        fi
    done
    local udev=/etc/udev/rules.d/90-backlight.rules
    if [[ ! -f $udev ]]; then
        echo 'ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chgrp video /sys/class/backlight/%k/brightness", RUN+="/bin/chmod g+w /sys/class/backlight/%k/brightness"' \
            | sudo tee "$udev" >/dev/null
        info "udev backlight rule created"
        changed=1
    else
        info "udev backlight rule already present"
    fi
    if [[ $changed == 1 ]]; then
        if [[ -f /boot/grub/grub.cfg ]]; then sudo grub-mkconfig -o /boot/grub/grub.cfg
        elif command -v update-grub &>/dev/null; then sudo update-grub; fi
        info "GRUB rebuilt — reboot to apply brightness fix"
    fi
}

# --- final notes ----------------------------------------------------------
step_done() {
    section "Done"
    cat <<EOF
Install finished. Worth checking / doing manually:
  • Reboot if shell, groups, or the GRUB backlight fix changed.
  • ~/.emacs.d and ~/.config are restored as git repos — 'git status' in each to confirm.
  • Verify ssh: ssh -T git@github.com
  • syncthing folders (~/DCIM, ~/Snapseed).
EOF
}
