#!/bin/bash

LIST="source/repos/cigi-ccl_4_0
source/repos/dotfiles
source/repos/ewow
source/repos/fd-find
source/repos/old-ada-mode
source/repos/scripts
source/repos/selected-window-accent-mode
source/repos/themes
source/repos/wowee
source/repos/wvkbd
source/repos/xcompose
source/repos/xkb-mode
source/repos/xkeymacs
.config
bin"

LIST="source/repos/cigi-ccl_4_0"

# create a git alias to revert permissions
git config --global --add alias.permission-reset '!git diff -p -R --no-ext-diff --no-color --diff-filter=M | grep -E "^(diff|(old|new) mode)" --color=never | git apply'
git config --global user.name "james@dyerdwelling.family"
git config --global user.email "james@dyerdwelling.family"
git config core.fileMode false

for item in $LIST; do
   echo $item
   cd ~/$item
   git permission-reset
   # git diff -p -R --no-ext-diff --no-color \
   #    | grep -E "^(diff|(old|new) mode)" --color=never \
   #    | git apply
done
