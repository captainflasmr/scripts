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
echo "Ready to sync to final directories? : Press <any key> to continue"
read -e RESPONSE

echo
echo "----------------------------------------"
echo "syncing data"
echo "----------------------------------------"
echo

NAS_RSYNC_LIST=(
    "DCIM"
    "source"
)

install_dirs
