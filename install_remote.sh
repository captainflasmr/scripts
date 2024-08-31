#!/bin/bash
# sync the latest github repos to my config

# intelligently get / update repos
function get_repos ()
{
   for repos in $2; do
      echo
      echo "----------------------------------------"
      echo "$1/${repos}"
      echo "----------------------------------------"
      echo
      curr_repos="$1/${repos}"
      if [[ ! -d "$repos" ]]; then
         echo "Cloning..."
         git clone "$curr_repos"
      else
         echo "Pulling..."
         pushd $repos
         git pull "$curr_repos"
         popd
      fi
   done
}

# themes
mkdir -p $HOME/source/repos/themes
cd $HOME/source/repos/themes
get_repos "git@github.com:captainflasmr" "hugo-bootstrap-gallery"
get_repos "https://github.com/Vimux" "Mainroad"

# others
mkdir -p $HOME/source/repos
cd $HOME/source/repos
get_repos "git@github.com:captainflasmr" "cigi-ccl_4_0 dotfiles fd-find old-ada-mode scripts selected-window-accent-mode wowee xkb-mode"
# get_repos "https://github.com/tkurtbond" "old-ada-mode"
get_repos "https://github.com/jjsullivan5196" "wvkbd"
get_repos "https://github.com/kragen" "xcompose"
get_repos "https://github.com/fujieda" "xkeymacs"
get_repos "https://github.com/zk-phi" "ewow"

echo
echo "Ready to sync to local directories? : Press <any key> to continue"
read -e RESPONSE

RSYNC_OPTS="-rltsiP --copy-links --modify-window=4"
SYNC_COMMANDS=(
  "dotfiles/ ${HOME}/.config/"
  "scripts/ ${HOME}/bin/"
)

confirm_sync() {
    echo
    echo "Sync $1 : Press 'y' to continue, any other key to skip"
    read -n 1 -s RESPONSE
    echo  # Move to a new line
    if [[ $RESPONSE = [yY] ]]; then
        return 0  # 0 is success/true in bash
    else
        return 1  # 1 is false
    fi
}

for ITEM in "${SYNC_COMMANDS[@]}"; do
    IFS=' ' read -r -a PATHS <<< "${ITEM}"
    if confirm_sync "${PATHS[1]}"; then
        RSYNC_CMD="rsync $RSYNC_OPTS \"${PATHS[0]}\" \"${PATHS[1]}\""
        echo "$RSYNC_CMD"
        eval "$RSYNC_CMD"
    else
        echo "Skipping sync for ${PATHS[1]}"
    fi
done

echo
echo "Sync $HOME/.profile? : Press <any key> to continue"
read -e RESPONSE
rsync -avP dotfiles/.profile $HOME/.profile
