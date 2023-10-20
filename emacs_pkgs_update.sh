#! /bin/bash
cd ~
mkdir -p emacs-pkgs/melpa
mkdir -p emacs-pkgs/elpa

echo
echo "updating MELPA..."
echo
rsync -avz --delete --progress rsync://melpa.org/packages/ ~/emacs-pkgs/melpa/.

echo
echo "updating ELPA..."
echo
rsync -avz --delete --progress elpa.gnu.org::elpa/. ~/emacs-pkgs/elpa

# org (currently no rsync support)
echo
echo "updating ORG..."
echo
cd ~/emacs-pkgs
git clone https://git.savannah.gnu.org/git/emacs/org-mode.git
# wget -r -l1 -nc -np https://orgmode.org/elpa
