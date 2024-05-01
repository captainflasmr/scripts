#!/bin/bash
RSYNC="rsync -rltsiP --no-g --copy-links --delete --size-only --modify-window=4 "

LOCAL_SRC="$HOME/DCIM/Art/Working/"
REMOTE_SRC="$HOME/nas/OneDrive/Documents/Art/"

if [[ $1 == "in" ]]; then
   RSYNC+=" \"${REMOTE_SRC}/\" \"${LOCAL_SRC}/\""
else
   RSYNC+=" \"${LOCAL_SRC}/\" \"${REMOTE_SRC}/\""
fi

eval "$RSYNC"
