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
        --exclude '.mbsyncpass*' \
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
    # NFS can't mount onto a missing dir; create ~/nas now so the first @reboot
    # mount (and a manual sync-from-nas.sh) works without hand-creating it.
    mkdir -p "$HOME/nas"
    info "mount point ready: $HOME/nas"
    case "$DISTRO" in
        arch) sudo pacman -S --needed --noconfirm cronie >/dev/null 2>&1
              sudo systemctl enable --now cronie ;;
        mint) "${APT[@]}" install -y cron >/dev/null 2>&1
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
# Arch only: that box launches its Wayland compositor from the shell, so a DM
# would just get in the way. Mint (Cinnamon/X11) needs its login manager, so we
# leave it well alone there.
step_disable_display_manager() {
    section "Display manager"
    if [[ $DISTRO != arch ]]; then
        info "keeping the display/login manager on $DISTRO (only disabled on Arch)"
        return 0
    fi
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

# --- USB quirk: JMicron 152d:a578 bridge (external Backup HDD) -------------
# This USB-SATA bridge (my external Backup drive's enclosure) has buggy UAS
# firmware that intermittently drops the link (uas_eh_device_reset /
# DID_NO_CONNECT / USB disconnect), causing slow or failed mounts and, worse,
# ext4 corruption that flips the filesystem read-only. Forcing plain BOT
# instead of UAS via a usb-storage quirk makes it rock solid. Distro-agnostic
# (/etc/modprobe.d is read by modprobe on both Arch and Debian/Mint). We do NOT
# reload the module here: during a USB-stick install, usb-storage is in use by
# the install medium itself — the quirk applies next time the module loads.
step_quirk_usb_uas() {
    confirm "Apply JMicron USB-SATA UAS quirk (external Backup drive fix)?" || { info "skipped"; return 0; }
    local conf=/etc/modprobe.d/usb-quirks.conf
    local id='152d:a578:u'
    if [[ -f $conf ]] && grep -qF "$id" "$conf"; then
        info "USB UAS quirk already present in $conf"
        return 0
    fi
    if [[ -f $conf ]] && grep -q '^options usb-storage quirks=' "$conf"; then
        # append our id to the existing comma-separated quirks list
        sudo sed -i -E "s/^(options usb-storage quirks=[^[:space:]]+)/\1,$id/" "$conf"
        info "appended $id to existing quirks line in $conf"
    else
        echo "options usb-storage quirks=$id" | sudo tee -a "$conf" >/dev/null
        info "wrote $conf (options usb-storage quirks=$id)"
    fi
    info "Takes effect next time usb-storage loads — replug the drive or reboot."
    info "Verify: dmesg | grep -i uas  -> expect 'UAS is ignored ... using usb-storage'"
}

# --- X11 keyboard: custom xkb keymap (Mint/Cinnamon) ----------------------
# Sway (Arch) loads this via the input `xkb_file` setting; X11 has no equivalent
# persistent config, so we compile the keymap into the running server at every
# login through an autostart entry. The .xkb file carries the sticky modifiers
# and the Caps/Right-Alt -> Ctrl remaps. No-op on Arch (sway handles it).
step_mint_keymap() {
    [[ $DISTRO == mint ]] || { info "xkb keymap: sway handles this on Arch — skipping"; return 0; }
    section "X11 keyboard keymap (sticky modifiers)"
    local keymap="$HOME/.emacs.d/Emacs-vanilla/keymap/keymap_with_sticky_modifiers.xkb"
    [[ -f $keymap ]] || { warn "keymap not found: $keymap (restore home first) — skipping"; return 0; }
    # xkbcomp ships in x11-xkb-utils on Debian/Mint.
    if ! command -v xkbcomp &>/dev/null; then
        info "installing x11-xkb-utils (provides xkbcomp)"
        "${APT[@]}" install -y x11-xkb-utils || warn "could not install x11-xkb-utils"
    fi
    # Autostart entry — re-applies on every login. The short sleep lets the
    # desktop's input daemon settle first so it doesn't clobber the keymap.
    local dir="$HOME/.config/autostart"; mkdir -p "$dir"
    local desktop="$dir/xkb-sticky-keymap.desktop"
    cat > "$desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Custom XKB keymap (sticky modifiers)
Comment=Compile keymap_with_sticky_modifiers.xkb into the X server at login
Exec=sh -c 'sleep 2; xkbcomp -w0 "\$HOME/.emacs.d/Emacs-vanilla/keymap/keymap_with_sticky_modifiers.xkb" "\$DISPLAY"'
OnlyShowIn=X-Cinnamon;XFCE;MATE;GNOME;
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF
    info "autostart written: $desktop"
    # Apply immediately if we're in an X11 session right now.
    if [[ -n ${DISPLAY:-} ]] && command -v xkbcomp &>/dev/null; then
        if xkbcomp -w0 "$keymap" "$DISPLAY" 2>/dev/null; then
            info "keymap applied to current display $DISPLAY"
        else
            warn "could not apply to $DISPLAY now (will apply at next login)"
        fi
    else
        info "no X11 display in this shell — will apply at next login"
    fi
}

# --- Cinnamon keybindings (Mint) ------------------------------------------
# Bespoke shortcuts via gsettings (persisted in dconf, so no autostart needed).
# Additive: appends our combo to whatever Cinnamon already binds, so the stock
# Ctrl+Alt+Arrow shortcuts keep working. No-op on Arch (sway has its own binds).
# Add more rows to the `binds` table below — "<schema-key> <accelerator>".
# Append an accelerator to a built-in WM action (additive, idempotent).
_kb_add() {  # _kb_add <schema> <key> <accelerator>
    local schema="$1" key="$2" combo="$3" cur
    cur=$(gsettings get "$schema" "$key" 2>/dev/null) || { warn "no such key: $key"; return 0; }
    if [[ $cur == *"'$combo'"* ]]; then info "$key already has $combo"; return 0; fi
    local newval
    if [[ $cur == "@as []" || $cur == "[]" ]]; then newval="['$combo']"
    else newval="${cur%]}, '$combo']"; fi
    if gsettings set "$schema" "$key" "$newval" 2>/dev/null; then info "$key += $combo"
    else warn "failed to set $key"; fi
}
# Define a Cinnamon custom keybinding that runs a command (idempotent: keyed by
# a stable slug, so re-running just updates it rather than duplicating).
_kb_custom() {  # _kb_custom <slug> <accelerator> <command> <friendly-name>
    local slug="$1" accel="$2" cmd="$3" name="$4"
    local base="org.cinnamon.desktop.keybindings"
    local ck="org.cinnamon.desktop.keybindings.custom-keybinding"
    local path="/org/cinnamon/desktop/keybindings/custom-keybindings/$slug/"
    gsettings set "$ck:$path" name    "$name" 2>/dev/null || { warn "custom $slug: set failed"; return 0; }
    gsettings set "$ck:$path" command "$cmd"   2>/dev/null
    gsettings set "$ck:$path" binding "['$accel']" 2>/dev/null
    local cur; cur=$(gsettings get "$base" custom-list 2>/dev/null)
    if [[ $cur != *"'$slug'"* ]]; then
        local newval
        if [[ $cur == "@as []" || $cur == "[]" ]]; then newval="['$slug']"
        else newval="${cur%]}, '$slug']"; fi
        gsettings set "$base" custom-list "$newval" 2>/dev/null
    fi
    info "custom: $accel -> $cmd"
}
step_mint_keybindings() {
    [[ $DISTRO == mint ]] || { info "keybindings: Cinnamon-only — skipping (sway has its own)"; return 0; }
    section "Cinnamon keybindings"
    command -v gsettings &>/dev/null || { warn "gsettings not found — skipping"; return 0; }
    local wm="org.cinnamon.desktop.keybindings.wm"
    if ! gsettings list-schemas 2>/dev/null | grep -qx "$wm"; then
        warn "$wm not available (not a Cinnamon session?) — skipping"; return 0
    fi

    # --- window-manager actions (ported from sway config.d/default) -------
    local -a binds=(
        "switch-to-workspace-left  <Super>u"          # sway: $mod+u workspace prev
        "switch-to-workspace-right <Super>i"          # sway: $mod+i workspace next
        "close                     <Super>q"          # sway: $mod+q kill
        "toggle-fullscreen         <Super>m"          # sway: $mod+m fullscreen
    )
    local n
    for n in 1 2 3 4 5 6 7 8; do                      # sway: $mod+N / $mod+Shift+N
        binds+=("switch-to-workspace-$n <Super>$n")
        binds+=("move-to-workspace-$n <Super><Shift>$n")
    done
    local row key combo
    for row in "${binds[@]}"; do
        read -r key combo <<< "$row"
        _kb_add "$wm" "$key" "$combo"
    done

    # --- application launchers (sway 'exec' binds -> Cinnamon customs) -----
    # Commands adapted for Mint/X11 (kitty not alacritty; no Wayland env vars).
    _kb_custom bs-term     "<Super>Return"   "kitty"                            "Terminal"
    _kb_custom bs-term-t   "<Super>t"        "kitty"                            "Terminal (t)"
    _kb_custom bs-firefox  "<Super>b"        "firefox"                          "Firefox"
    _kb_custom bs-files    "<Super>e"        "thunar $HOME/DCIM/Camera"         "Files (DCIM/Camera)"
    _kb_custom bs-mail     "<Super>n"        "thunderbird"                      "Thunderbird"
    _kb_custom bs-emacs    "<Super>x"        "emacsclient -c -a emacs"          "Emacs"
    _kb_custom bs-thanos   "<Super>z"        "emacsclient --eval '(thanos/type)'" "Emacs thanos/type"
    _kb_custom bs-shot     "<Super><Shift>s" "$HOME/bin/screenshot.sh"          "Screenshot"
    _kb_custom bs-rofi     "<Super>slash"    "rofi -matching regex -show drun"  "Rofi (app launcher)"
}

# --- touchpad gestures (Mint/Cinnamon) ------------------------------------
# libinput-gestures is not in the Mint apt repos, so we clone upstream and
# install it. Maps 4-finger swipes to Cinnamon's workspace-switch shortcuts
# (ctrl+alt+Left/Right), leaving Cinnamon's built-in 3-finger gestures alone.
# No-op on Arch (sway has its own gesture bindings).
step_mint_touchpad_gestures() {
    [[ $DISTRO == mint ]] || { info "touchpad gestures: sway handles this on Arch — skipping"; return 0; }
    section "Touchpad gestures (libinput-gestures)"
    # Deps should already be in mint-apt.txt, but install defensively (the keymap
    # step does the same for x11-xkb-utils).
    local -a deps=( libinput-tools xdotool wmctrl )
    local d
    for d in "${deps[@]}"; do
        if ! dpkg -s "$d" &>/dev/null; then
            info "installing $d"
            "${APT[@]}" install -y "$d" || warn "could not install $d"
        fi
    done

    # Install libinput-gestures from upstream if the command is missing.
    if ! command -v libinput-gestures &>/dev/null; then
        local tmp; tmp=$(mktemp -d)
        info "cloning libinput-gestures -> $tmp"
        git clone --depth 1 https://github.com/bulletmark/libinput-gestures.git "$tmp/libinput-gestures" \
            || { warn "clone failed — skipping gesture setup"; rm -rf "$tmp"; return 0; }
        ( cd "$tmp/libinput-gestures" && sudo ./libinput-gestures-setup install ) \
            || { warn "libinput-gestures-setup install failed"; rm -rf "$tmp"; return 0; }
        rm -rf "$tmp"
    else
        info "libinput-gestures already installed"
    fi

    # Write the config if missing (don't clobber user customisations on re-run).
    local cfg_dir="$HOME/.config"; mkdir -p "$cfg_dir"
    local cfg="$cfg_dir/libinput-gestures.conf"
    if [[ ! -f $cfg ]]; then
        cat > "$cfg" <<'EOF'
gesture swipe left 4  xdotool key ctrl+alt+Right
gesture swipe right 4 xdotool key ctrl+alt+Left
EOF
        info "config written: $cfg"
    else
        info "config already present: $cfg"
    fi

    # Enable now + on login. Idempotent.
    if command -v libinput-gestures-setup &>/dev/null; then
        libinput-gestures-setup autostart start || warn "autostart start failed"
        info "libinput-gestures enabled (autostart + running)"
    else
        warn "libinput-gestures-setup not on PATH — log out/in or re-run this step"
    fi
}

# --- mu / mu4e email index ------------------------------------------------
# Reads personal addresses from .mbsyncrc so nothing is hardcoded here.
step_mu_init() {
    section "mu / mu4e email index"
    command -v mu &>/dev/null || { warn "mu not installed, skipping"; return 0; }
    local maildir="$HOME/Maildir"
    [[ -d $maildir ]] || { warn "$maildir not found — run mbsync first, then re-run this step"; return 0; }
    [[ -f $HOME/.mbsyncrc ]] || { warn "no .mbsyncrc found — restore secrets first"; return 0; }
    local -a addrs=()
    while IFS= read -r addr; do
        addrs+=("--my-address=$addr")
    done < <(grep -i "^User " "$HOME/.mbsyncrc" | awk '{print $2}')
    [[ ${#addrs[@]} -eq 0 ]] && { warn "no User entries found in .mbsyncrc, skipping"; return 0; }
    if mu info &>/dev/null; then
        info "mu database already initialised"
    else
        info "initialising mu database (maildir=$maildir)"
        mu init --maildir="$maildir" "${addrs[@]}"
    fi
    info "indexing mail"
    mu index
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
  • Email: ensure .mbsyncpass-{james,jimbob,captainflasmr} are in the secrets archive.
  • Run 'mbsync -a' to fetch new mail, then 'mu index' to update the search index.
EOF
}
