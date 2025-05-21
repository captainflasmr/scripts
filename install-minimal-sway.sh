#!/bin/bash
set -e

# 1. Ensure root
# if [[ $EUID -ne 0 ]]; then
   # echo "Please run as root (sudo $0)"
   # exit 1
# fi

echo "Updating system first..."
sudo zypper --non-interactive refresh
sudo zypper --non-interactive update

echo
echo "----------------------------------------"
echo "installing emacs"
echo "----------------------------------------"
echo
sudo zypper -Sy --noconfirm --needed emacs-wayland

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

# 2. Install SwayWM and minimal dependencies
# echo "Installing SwayWM and dependencies..."
# zypper --non-interactive install sway waybar foot dunst alacritty thunar polkit-gnome wl-clipboard grim slurp rofi network-manager-applet

# 3. Install additional apps from install_apps.txt (PACMAN section only)
echo "Installing additional minimal apps..."

PACMAN_APPS=$(awk '/### PACMAN ###/,/### AUR ###/' install_apps-minimal-sway.txt | sed '/### PACMAN ###\|### AUR ###/d' | grep -v '^#' | tr '\n' ' ')
if [[ -n "$PACMAN_APPS" ]]; then
  sudo zypper --non-interactive install $PACMAN_APPS || true
fi

echo "----------------------------------------"
echo "checking cron"
echo "----------------------------------------"
echo "Installing cronie..."
sudo zypper -Sy --noconfirm --needed cronie
sudo systemctl enable cronie
sudo systemctl start cronie

echo
echo "----------------------------------------"
echo "installing cron"
echo "----------------------------------------"
echo
CRON_JOB="@reboot /home/jdyer/bin/startup_root.sh"
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
fi

# 4. Mount NAS & copy bin/.config
echo "Mounting NAS and copying user bin/.config..."

NAS_MOUNT="/home/jdyer/nas/Home"

mkdir -p "/home/jdyer/nas"

while [[ ! -d $NAS_MOUNT ]]; do
   # mount -t nfs captainflasmr:/volume1/Drive /home/jdyer/nas
   sudo mount -v -t nfs 192.168.0.19:/volume1/Drive /home/jdyer/nas
   sleep 2
done

# Copy bin and .config (adjust source directory as needed)
cp -r $NAS_MOUNT/bin $HOME/
cp -r $NAS_MOUNT/.config $HOME/
chown -R $USER:$USER $HOME/bin $HOME/.config

echo
echo "----------------------------------------"
echo "installing keys"
echo "----------------------------------------"
echo
rsync -avP $NAS_MOUNT/.gnupg/ $NAS_MOUNT/.gnupg/
rsync -avP $NAS_MOUNT/.ssh/ $HOME/.ssh/
/home/jdyer/bin//permissions-key.sh

# 5. Enable greetd or set Sway as default session (optional)
echo
echo "All done. You can now start Sway with 'sway' or configure greetd/ly for auto-login."
