#===================================================
# START INSTRUCTIONS
#===================================================

pacman -Sy --needed openssh
systemctl enable sshd
passwd
ip address

# Connect to ssh on your machine `root@ip`

ssh root@<ip_address>

#===================================================
# INSTRUCTIONS
#===================================================

loadkeys pl;
timedatectl

cfdisk /dev/vda
# here create two partitions one for BIOS small 100M and rest linux filesystem 

mkfs.btrfs -f -n 32k /dev/vda2;
mount /dev/vda2 /mnt

btrfs su cr /mnt/@;
btrfs su cr /mnt/@home;
btrfs su cr /mnt/@log;
btrfs su cr /mnt/@swap;
btrfs su cr /mnt/@pacman;
btrfs su cr /mnt/@tmp;
btrfs su cr /mnt/@snapshots

umount /mnt;
mount -o noatime,compress=lzo,space_cache=v2,subvol=@ /dev/vda2 /mnt;
mkdir -p /mnt/{home,var/log,var/tmp,var/cache/pacman/pkg,.snapshots,swap};
mount -o noatime,compress=lzo,space_cache=v2,subvol=@home /dev/vda2 /mnt/home;
mount -o noatime,compress=lzo,space_cache=v2,subvol=@log /dev/vda2 /mnt/var/log;
mount -o noatime,compress=lzo,space_cache=v2,subvol=@tmp /dev/vda2 /mnt/var/tmp;
mount -o noatime,compress=lzo,space_cache=v2,subvol=@pacman /dev/vda2 /mnt/var/cache/pacman/pkg;
mount -o noatime,compress=lzo,space_cache=v2,subvol=@snapshots /dev/vda2 /mnt/.snapshots

reflector --country Poland,Iceland --protocol https --age 12 --sort rate --save /etc/pacman.d/mirrorlist;
pacstrap -K /mnt base base-devel btrfs-progs git grub grub-btrfs inotify-tools linux linux-firmware linux-headers man neovim networkmanager openssh reflector snapper sudo

genfstab -U /mnt >> /mnt/etc/fstab;
arch-chroot /mnt

ln -sf /usr/share/zoneinfo/Atlantic/Reykjavik /etc/localtime;
hwclock --systohc;
echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen;
locale-gen;
echo LANG=en_US.UTF-8 >> /etc/locale.conf;
echo KEYMAP=pl >> /etc/vconsole.conf

my_hostname=<hostname>;
echo $my_hostname > /etc/hostname;
echo "127.0.0.1   localhost"$'\n'"127.0.1.1   $my_hostname.localdomain $my_hostname"$'\n'"::1         localhost" >> /etc/hosts

my_username=<username>;
passwd;
useradd -m -g users -G wheel $my_username;
passwd $my_username

EDITOR=nvim visudo
#
# Uncomment line with wheel %wheel ALL=(ALL) ALL
#
swap_size=8;
sudo mount -o subvol=@swap /dev/vda2 /swap;
btrfs filesystem mkswapfile --size "$swap_size"g --uuid clear /swap/swapfile;
swapon /swap/swapfile

# Edit fstab and add swap entry
echo '/swap/swapfile    none    swap     defaults   0   0' >> /etc/fstab

systemctl enable NetworkManager;
systemctl enable sshd;
grub-install /dev/vda;
grub-mkconfig -o /boot/grub/grub.cfg;
exit

umount -R /mnt;
reboot

#===================================================
# END INSTRUCTIONS
#===================================================

# POST INSTALLATOIN
# INFO if need to connect to the wifi you can use: `nmtui`

# INFO Install KDE Plasma and kscreen for screen management
# INFO Install graphic card drivers for intel dedicated graphics
sudo pacman -S intel-ucode pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber;
sudo pacman -S plasma-desktop kscreen;
sudo pacman -S firefox kitty;
sudo pacman -S xf86-video-intel 

#Display managers are useful when you have multiple DE or WMs and want to choose where to boot from in a GUI fashion, also they take care of the launch process.

# Install SDDM
sudo pacman -S sddm;
sudo systemctl enable sddm;
sudo pacman -S --needed sddm-kcm

# INFO configure snapper
# https://wiki.archlinux.org/title/Snapper point 5.3.1
# WARN `inotify-tools` are required before setup
# WARN swapfile is crashing snapshots use swapoff

sudo umount /.snapshots;
sudo rm -r /.snapshots;
sudo snapper -c root create-config /;
sudo btrfs sub del /.snapshots/;
sudo mkdir /.snapshots

# ensure that snapshots are in fstab

sudo mount -o subvol=@snapshots /dev/vda2 /.snapshots;
sudo mount -a;
sudo chmod 750 /.snapshots

# INFO snapper configuration is inside /etc/snapper/configs/root

sudo nvim /etc/snapper/configs/root
# ALLOW_USERS="my_username"
# ALLOW_GROUPS="my_group" eg `wheel`
# # My settings for automatic snapshots
# TIMELINE_MIN_AGE="1800"
# TIMELINE_LIMIT_HOURLY="5"
# TIMELINE_LIMIT_DAILY="7"
# TIMELINE_LIMIT_WEEKLY="0"
# TIMELINE_LIMIT_MONTHLY="3"
# TIMELINE_LIMIT_YEARLY="5"
#
# INFO To disable hourly snapshots set below to "no"
# TIMELINE_CREATE="no"

# To enable scheduled snapshots enable cronie, all configuration is in above file

sudo pacman -S --needed cronie;
systemctl enable cronie.service

# This is not needed if you have cronie
# sudo systemctl enable --now snapper-timeline.timer
# sudo systemctl enable --now snapper-cleanup.timer

# To enable that snapshots show up in GRUB Enable grub-btrfs.path to refresh the shapshot list

sudo systemctl enable grub-btrfsd

# INFO configure snapper and grub-btrfs https://github.com/Antynea/grub-btrfs 
# To manually generate grub snapshot entries you can run:
# sudo /etc/grub.d/41_snapshots-btrfs

# update grub
sudo grub-mkconfig -o /boot/grub/grub.cfg


# INFO Fix restore ro snapshots from grub
# Instructions for Arch: https://github.com/Antynea/grub-btrfs/blob/master/initramfs/readme.md

git clone https://github.com/Antynea/grub-btrfs.git;
sudo cp grub-btrfs/initramfs/Arch\ Linux/overlay_snap_ro-install /etc/initcpio/install/grub-btrfs-overlayfs;
sudo cp grub-btrfs/initramfs/Arch\ Linux/overlay_snap_ro-hook /etc/initcpio/hooks/grub-btrfs-overlayfs;
rm -rdf grub-btrfs

# edit /etc/mkinitcpio.conf file and add `grub-btrfs-overlayfs` at the end of the line HOOKS=(... grub-btrfs-overlayfs)
sudo nvim /etc/mkinitcpio.conf

# regenerate mkinitcpio
sudo mkinitcpio -P

# INFO automatically create snapshots on pacman crud 
# https://github.com/wesbarnett/snap-pac
sudo pacman -S snap-pac


# TODO Enable hibernation



# TODO edit /etc/mkinitcpio.conf
# add `MODULES=(btrfs)` to MODULES
# `mkinitcpio -p linux` - regenerate initramfs
