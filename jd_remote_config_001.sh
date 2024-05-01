#!/bin/bash
# sync the latest github repos to my config

mkdir -p $HOME/repos

cd $HOME/repos

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

get_repos "git@github.com:captainflasmr" "dotfiles fd-find selected-window-accent-mode scripts"
get_repos "https://github.com/tkurtbond" "old-ada-mode"
get_repos "https://github.com/jjsullivan5196" "wvkbd"

echo
echo "Ready to sync to local directories? : Press <any key> to continue"
read -e RESPONSE

RSYNC="rsync -rltsiP --copy-links --modify-window=4 "

echo
echo "Sync $HOME/.config? : Press <any key> to continue"
read -e RESPONSE
CMD+="$RSYNC \"dotfiles/\" \"${HOME}/.config/\""
echo "$CMD"
eval "$CMD"
echo
echo "Sync $HOME/bin? : Press <any key> to continue"
read -e RESPONSE
CMD+="$RSYNC \"scripts/\" \"${HOME}/bin/\""
echo "$CMD"
eval "$CMD"
echo
echo "Sync $HOME/.profile? : Press <any key> to continue"
read -e RESPONSE
rsync -avP dotfiles/.profile $HOME/.profile
