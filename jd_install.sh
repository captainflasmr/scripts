#!/bin/bash
# my installation script post arch install

function install_yay ()
{
   if ! command -v yay &> /dev/null ; then
      echo "Installing yay"
      sudo pacman -S --needed git base-devel
      cd /tmp
      git clone https://aur.archlinux.org/yay-bin.git
      cd yay-bin
      makepkg -si
   fi
}

install_yay

# enable nas
mkdir -p ~/nas

# install from pacman / AUR
if command -v yay &> /dev/null ; then
   echo
   echo "----------------------------------------"
   echo "Doing pacman install"
   echo "----------------------------------------"
   echo
   LIST=$(cat "/$HOME/bin/jd_install.txt")
   echo $LIST
   for file in $LIST; do
      if ! pacman -Qi $file &> /dev/null; then
         echo "----------------------------------------"
         echo "PKG : Doing $file"
         echo "----------------------------------------"
         yay -Sy --noconfirm --needed $file
      else
         echo "----------------------------------------"
         echo "PKG : SKIPPING $file"
         echo "----------------------------------------"
      fi
   done

   echo
   echo "----------------------------------------"
   echo "Doing AUR install"
   echo "----------------------------------------"
   echo
   LIST=$(cat "/$HOME/bin/jd_install_aur.txt")
   echo $LIST
   for file in $LIST; do
      if ! pacman -Qi $file &> /dev/null; then
         echo "----------------------------------------"
         echo "AUR : Doing $file"
         echo "----------------------------------------"
         yay -Sy --noconfirm --needed $file
      else
         echo "----------------------------------------"
         echo "PKG : SKIPPING $file"
         echo "----------------------------------------"
      fi
   done
fi

exit

# flatpaks
if command -v flatpak &>/dev/null; then
   echo
   echo "----------------------------------------"
   echo "Doing flatpak install"
   echo "----------------------------------------"
   echo
   LIST="$HOME/bin/jd_install-flatpak.txt"
   while read -r app_id; do
      echo "Installing $app_id ..."
      flatpak install -y "$app_id"
      echo "-------------------------"
   done < "$LIST"
fi

# switch shells
if command -v fish &> /dev/null ; then
   chsh -s /usr/bin/fish
fi

# make sure cronie is enabled
if pacman -Qi cronie &> /dev/null ; then
   sudo systemctl enable cronie
fi

# enable kmonad keys
sudo usermod -aG input jdyer
