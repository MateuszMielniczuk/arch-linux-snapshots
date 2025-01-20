#===================================================
# POST INSTALLATION script
#===================================================

echo 'Updating system'
sudo -Syu

echo 'Installing graphic drivers'
sudo pacman -S xorg-server
sudo pacman -S xf86-video-intel mesa lib32-mesa

echo 'Installing CPU drivers'
sudo pacman -S intel-ucode
echo 'Installing sound drivers'
sudo pacman -S pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber


echo 'Installing DM and KDE plasma'
sudo pacman -S plasma-desktop kscreen

sudo pacman -S sddm
sudo systemctl enable sddm
sudo pacman -S --needed sddm-kcm

