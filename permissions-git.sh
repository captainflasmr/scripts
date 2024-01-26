#!/bin/bash

LIST="repos/wvkbd
repos/qtdoc
DCIM/Art/Content/ArtAssets
DCIM/Art/Content/ArtRage
DCIM/Art/Content/ArtRagePenTool
DCIM/Art/Content/ArtRageTabletFriend
DCIM/Art/Content/InfinitePainter
DCIM/Art/Content/Krita
DCIM/themes/hugo-bootstrap-gallery
DCIM/themes/Hugo-Octopress
DCIM/themes/hugo-theme-notrack
DCIM/themes/hugo-xmag
DCIM/themes/Mainroad
repos/fd-find
repos/old-ada-mode
repos/dotfiles
.config
"

# create a git alias to revert permissions
git config --global --add alias.permission-reset '!git diff -p -R --no-ext-diff --no-color --diff-filter=M | grep -E "^(diff|(old|new) mode)" --color=never | git apply'
git config --global user.name "james@dyerdwelling.family"
git config --global user.email "james@dyerdwelling.family"

for item in $LIST; do
   echo $item
   cd ~/$item
   git permission-reset
   # git diff -p -R --no-ext-diff --no-color \
   #    | grep -E "^(diff|(old|new) mode)" --color=never \
   #    | git apply
done
