#!/bin/bash
# my installation script post arch install

COMBINED_LIST="$HOME/bin/install_apps.txt"

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

function install_paru ()
{
   if ! command -v paru &> /dev/null ; then
      echo "Installing paru"
      sudo pacman -S --needed git base-devel
      cd /tmp
      git clone https://aur.archlinux.org/paru-bin.git
      cd paru-bin
      makepkg -si
   fi
}

function remove_packages ()
{
   echo "The following packages will be removed:"
   echo "$LIST"

   # Confirmation prompt
   read -p "Are you sure you want to remove these packages? [y/N] " response
   case "$response" in
      [yY][eE][sS]|[yY])
          for file in $LIST; do
             $AUR_HELPER -Rns --noconfirm $file
          done
          ;;
      *)
          echo "Operation aborted."
          ;;
   esac
}

# Choosing the AUR helper
read -p "Choose your AUR helper (yay/paru): " AUR_CHOICE
case "$AUR_CHOICE" in
   yay)
      AUR_HELPER="yay"
      install_yay
      ;;
   paru)
      AUR_HELPER="paru"
      install_paru
      ;;
   *)
      echo "Invalid option. Exiting."
      exit 1
      ;;
esac

if [[ "$@" == *"--remove"* ]]; then
   LIST=$(awk '/### REMOVE ###/,/### PACMAN ###/' "$COMBINED_LIST" | sed '/### REMOVE ###\|### PACMAN ###/d')
   remove_packages
   exit
fi

# Enable nas
mkdir -p ~/nas

# Install from pacman / AUR
if command -v $AUR_HELPER &> /dev/null ; then
   echo
   echo "----------------------------------------"
   echo "Doing pacman install"
   echo "----------------------------------------"
   echo
   LIST=$(awk '/### PACMAN ###/,/### AUR ###/' "$COMBINED_LIST" | sed '/### PACMAN ###\|### AUR ###/d')
   for file in $LIST; do
      if ! pacman -Qi $file &> /dev/null; then
         echo "----------------------------------------"
         echo "PKG : Doing $file"
         echo "----------------------------------------"
         $AUR_HELPER -Sy --noconfirm --needed $file
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
   LIST=$(awk '/### AUR ###/,/### FLATPAK ###/' "$COMBINED_LIST" | sed '/### AUR ###\|### FLATPAK ###/d')
   for file in $LIST; do
      if ! pacman -Qi $file &> /dev/null; then
         echo "----------------------------------------"
         echo "AUR : Doing $file"
         echo "----------------------------------------"
         $AUR_HELPER -Sy --noconfirm --needed $file
      else
         echo "----------------------------------------"
         echo "AUR : SKIPPING $file"
         echo "----------------------------------------"
      fi
   done
fi

# Flatpaks installation
if command -v flatpak &>/dev/null; then
   echo
   echo "----------------------------------------"
   echo "Doing flatpak install"
   echo "----------------------------------------"
   echo
   LIST=$(awk '/### FLATPAK ###/,/### END ###/' "$COMBINED_LIST" | sed '/### FLATPAK ###\|### END ###/d')
   echo "$LIST" | while read -r file; do
      echo "Installing $file ..."
      flatpak install -y "$file"
      echo "-------------------------"
   done
fi
