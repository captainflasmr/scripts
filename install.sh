#!/bin/bash

CUR_DIR=$PWD
BIN_DIR=$CUR_DIR/Home/bin

# check we are in the correct location
if [[ ! -d "$BIN_DIR" ]]; then
   echo "Error: 'Home' folder not found in the current directory."
   echo "Please locate to the correct location and re-run the script."
   exit 1
fi

# first update the system
# $BIN_DIR/upall.sh

echo "Home folder found. Proceeding with the script."

# install emacs, the saviour!
sudo pacman -S emacs

# make sure ssh and keys are correct
# firstly we need to sync across .gnupg and .ssh and set permissions
echo $BIN_DIR
rsync -avP $CUR_DIR/Home/.gnupg/ $HOME/.gnupg/
rsync -avP $CUR_DIR/Home/.ssh/ $HOME/.ssh/
$BIN_DIR/permissions-key.sh

# now get git remote repos
# which will also sync to the correct locations
# this should sort out the git permissions
$BIN_DIR/jd_remote_config.sh

# sync across data without the gits
RSYNC="rsync -rltsiP --copy-links \
    --exclude '.git' --exclude '.gitignore' "
CMD+="$RSYNC \"${CUR_DIR}/Home/\" \"${HOME}/\""
echo "$CMD"
eval "$CMD"

# and now install all the apps
$BIN_DIR/jd_install.sh
