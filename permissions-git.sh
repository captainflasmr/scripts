#!/bin/bash

LIST="source/repos/bank-buddy
source/repos/dired-image-thumbnail
source/repos/dired-video-thumbnail
source/repos/evie
source/repos/html-to-org
source/repos/jira-to-org
source/repos/meal-planner
source/repos/melpa
source/repos/melpazoid
source/repos/ollama-buddy
source/repos/selected-window-accent-mode
source/repos/simply-annotate
source/repos/stuff
source/repos/themes
source/repos/wvkbd
source/repos/xkb-mode"

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
