#!/bin/bash
mkdir -p $HOME/repos
cd $HOME/repos

git clone https://github.com/captainflasmr/dotfiles
git clone https://github.com/captainflasmr/fd-find
git clone https://github.com/captainflasmr/scripts

git clone https://github.com/tkurtbond/old-ada-mode

rsync -avP dotfiles/ $HOME/.config/

rsync -avP dotfiles/.profile $HOME/.profile
