#!/bin/bash

function install_dirs ()
{
    for entry in "${NAS_RSYNC_LIST[@]}"; do
        src_dir=$(echo $entry | awk '{print $1}')
        dest_dir=$(echo $entry | awk '{print $2}')
        if [[ -z "$dest_dir" ]]; then
            dest_dir="$src_dir"
        fi
        echo "Rsyncing $NAS_MOUNT/$src_dir to $HOME/$dest_dir ..."
        rsync -a --delete "$NAS_MOUNT/$src_dir/" "$HOME/$dest_dir/"
        chown -R $USER:$USER "$HOME/$dest_dir"
    done
}

echo
echo "----------------------------------------"
echo "system update"
echo "----------------------------------------"
echo
if command -v garuda-update &> /dev/null ; then
    echo "----------------------------------------"
    echo "garuda-update"
    echo "----------------------------------------"
    sudo garuda-update
else
    sudo pacman -Syu --noconfirm
fi

echo
echo "----------------------------------------"
echo "flatpak update"
echo "----------------------------------------"
echo
if command -v flatpak &> /dev/null ; then
    flatpak upgrade
fi

echo
echo "----------------------------------------"
echo "installing emacs"
echo "----------------------------------------"
echo
sudo pacman -Sy --noconfirm --needed emacs

echo "----------------------------------------"
echo "checking cron"
echo "----------------------------------------"
echo "Installing cronie..."
sudo pacman -Sy --noconfirm --needed cronie
sudo systemctl enable cronie
sudo systemctl start cronie

echo
echo "----------------------------------------"
echo "installing cron"
echo "----------------------------------------"
echo
CRON_JOB="@reboot $HOME/bin/startup_root.sh"
if ! sudo crontab -l | grep -Fxq "$CRON_JOB"; then
    (sudo crontab -l; echo "$CRON_JOB") | sudo crontab -
    echo "Cron job added successfully."
else
    echo "Cron job already exists. No action taken."
fi

echo "----------------------------------------"
echo "setting usermod"
echo "----------------------------------------"
if ! groups $USER | grep -q '\binput\b'; then
    sudo usermod -aG input $USER
    sudo usermod -aG audio $USER
fi

# echo
# echo "----------------------------------------"
# echo "pulling git repos"
# echo "----------------------------------------"
# echo
# ./install_remote.sh

echo
echo "----------------------------------------"
echo "mounting nas"
echo "----------------------------------------"
echo
NAS_MOUNT="$HOME/nas/Home"

mkdir -p "$HOME/nas"

while [[ ! -d $NAS_MOUNT ]]; do
    # mount -t nfs captainflasmr:/volume1/Drive $HOME/nas
    sudo mount -v -t nfs 192.168.0.19:/volume1/Drive $HOME/nas
    sleep 2
done

echo
echo "----------------------------------------"
echo "syncing data"
echo "----------------------------------------"
echo
# Define directories to sync: "source [destination]"
NAS_RSYNC_LIST=(
    "bin"
    ".config"
)

install_dirs

# Now copy some important profile files
SRC_DIR="$HOME/nas/Home"
DST_DIR="$HOME"

files=(
    .authinfo
    .authinfo.gpg
    .bash_history
    .bash_logout
    .bash_profile
    .bashrc
    .profile
    .ignore
)

for f in "${files[@]}"; do
    rsync -av "$SRC_DIR/$f" "$DST_DIR/$f"
done

echo
echo "----------------------------------------"
echo "installing keys"
echo "----------------------------------------"
echo
rsync -avP $NAS_MOUNT/.gnupg/ $HOME/.gnupg/
rsync -avP $NAS_MOUNT/.ssh/ $HOME/.ssh/
$HOME/bin/permissions-key.sh

echo
echo "----------------------------------------"
echo "installing apps"
echo "----------------------------------------"
echo
$HOME/bin/install_apps.sh

echo "----------------------------------------"
echo "checking shell"
echo "----------------------------------------"
if command -v fish &> /dev/null; then
    CURRENT_SHELL=$(getent passwd $USER | cut -d: -f7)
    if [ "$CURRENT_SHELL" != "/usr/bin/fish" ]; then
        chsh -s /usr/bin/fish
        echo "Switched to fish shell."
    else
        echo "Fish shell is already the default."
    fi
fi

echo
echo "----------------------------------------"
echo "other stuff"
echo "----------------------------------------"
echo
# build wvkbd
# Modify the GRUB config file sudo /etc/default/grub
# GRUB_CMDLINE_LINUX_DEFAULT append "i915.enable_dpcd_backlight=3" then save the file
# sudo grub-mkconfig -o /boot/grub/grub.cfg

echo
echo "Ready to sync to final directories? : Press <any key> to continue"
read -e RESPONSE

NAS_RSYNC_LIST=(
    "DCIM"
    "source"
    "wallpaper"
)

install_dirs

echo
echo "----------------------------------------"
echo "cleaning up"
echo "----------------------------------------"
echo
# rm -fr $HOME/.emacs.d
