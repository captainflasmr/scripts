#!/bin/bash
# the script to install all my stuff after a basic arch / sway type of
# install.  The location will have to be where the Home folder resides
# on the external driver

CUR_DIR=$PWD
BIN_DIR=$CUR_DIR/Home/bin

if [[ ! -d "$BIN_DIR" ]]; then
   echo "Error: 'Home' folder not found in the current directory."
   echo "Please locate to the correct location and re-run the script."
   exit 1
fi

$BIN_DIR/upall.sh

echo
echo "----------------------------------------"
echo "installing emacs"
echo "----------------------------------------"
echo
sudo pacman -Sy --noconfirm --needed emacs

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

echo "----------------------------------------"
echo "checking cron"
echo "----------------------------------------"
if systemctl list-unit-files --type=service | grep -qw 'cronie.service'; then
  if ! systemctl is-active --quiet cronie; then
    echo "Enabling and starting cronie service..."
    sudo systemctl enable cronie
    sudo systemctl start cronie
  else
    echo "cronie service is already running."
  fi
else
   echo "cronie service is not installed."
   echo "Installing cronie..."
   pacman -Sy --noconfirm --needed cronie
   echo "Enabling and starting cronie service..."
   sudo systemctl enable cronie
   sudo systemctl start cronie
fi

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

echo
echo "----------------------------------------"
echo "installing keys"
echo "----------------------------------------"
echo
rsync -avP $CUR_DIR/Home/.gnupg/ $HOME/.gnupg/
rsync -avP $CUR_DIR/Home/.ssh/ $HOME/.ssh/
$BIN_DIR/permissions-key.sh

echo
echo "----------------------------------------"
echo "pulling git repos"
echo "----------------------------------------"
echo
$BIN_DIR/install_remote.sh

echo
echo "----------------------------------------"
echo "syncing data"
echo "----------------------------------------"
echo
RSYNC="rsync -rltsiP --copy-links \
    --exclude '.git' --exclude '.gitignore' "
CMD+="$RSYNC \"${CUR_DIR}/Home/\" \"${HOME}/\""
echo "$CMD"
eval "$CMD"

echo
echo "----------------------------------------"
echo "installing apps"
echo "----------------------------------------"
echo
$BIN_DIR/install_apps.sh

echo
echo "----------------------------------------"
echo "other stuff"
echo "----------------------------------------"
echo
# build wvkbd

echo
echo "----------------------------------------"
echo "cleaning up"
echo "----------------------------------------"
echo
rm -fr $HOME/.emacs.d
