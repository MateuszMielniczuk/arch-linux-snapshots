# Arch Linux + snapshots + KDE Plasma test on VM

## 🔎 Description:

Instructions for installing and configuring a Linux system based on Arch Linux with snapshot functionality.
System uses required BTRFS partitions, Snapper for snapshots and KDE Plasma desktop. This setup is used for testing on a VM machine.
These instructions are based on arch wiki and [installanion guide](https://wiki.archlinux.org/title/Installation_guide).
All was tested with `Qemu` virtual manager and `archlinux-2024.11.01` ISO.

## ✨ Features:

- Create and restore system snapshots using Snapper
- BTRFS system partition - required for system snapshots
- Create automatic snapshots before and after system and software updates with btrfs-xxxx
- Restore the system from the boot menu with grub-btrfs
- Desktop Environment - KDE Plasma

## Table of contents

- [Installation setup](#----installation-setup)
  * [SSH connection](#ssh-connection--optional-)
  * [Setting up the keyboard layout](#setting-up-the-keyboard-layout)
  * [Connect to the Internet](#connect-to-the-internet)
  * [Update the system clock](#update-the-system-clock)
- [Partitioning](#---partitioning)
  * [Creating and formatting partitions](#creating-and-formatting-partitions)
  * [Creating subvolumes](#creating-subvolumes)
- [System installation](#---system-installation)
  * [Setting up mirrors for faster downloads](#setting-up-mirrors-for-faster-downloads)
  * [Install base system and libraries](#install-base-system-and-libraries)
  * [Generate fstab file](#generate-fstab-file)
- [Chroot](#---chroot)
  * [Set the date and time](#set-the-date-and-time)
  * [Set locale](#set-locale)
  * [Set hostname and hosts](#set-hostname-and-hosts)
  * [Set root password and create user](#set-root-password-and-create-user)
  * [Enable network manager and ssh services](#enable-network-manager-and-ssh-services)
  * [Create and enable swapfile](#create-and-enable-swapfile)
  * [Installing and configuring the GRUB boot loader](#installing-and-configuring-the-grub-boot-loader)
- [Configure snapper](#configure-snapper)
  * [Snapper configuration](#snapper-configuration)
  * [Restore snapshots from grub menu](#restore-snapshots-from-grub-menu)
  * [Fix restore read only snapshots from GRUB](#fix-restore-read-only-snapshots-from-grub)
  * [Auto create snapshots before and after running pacman](#auto-create-snapshots-before-and-after-running-pacman)
- [Post installation steps](#---post-installation-steps)
  * [Install desktop environment](#install-desktop-environment)
  * [Install browser and terminal](#install-browser-and-terminal)
  * [Install graphic card drivers for intel dedicated graphics](#install-graphic-card-drivers-for-intel-dedicated-graphics)
  * [Install SDDM](#install-sddm)

## 🛠️ Installation setup <a name="----installation-setup"></a>

### SSH connection (optional) <a name="#ssh-connection--optional-"></a>

If the device and VM are connected to the same Internet, which is usually the case with Virtual Manager installed on the local computer, it is easy to connect via SSH and use the local computer's terminal to install Arch. This is a more convenient option. It is easier to change the font size, scroll through the terminal window to see older commands and output.

First install ssh on the VM Arch installation, enable the ssh service and set the ISO root password for security.

```sh
pacman -Sy --needed openssh;
systemctl enable sshd;
passwd
```

Check your IP addres

```sh
ip address
```

Now connect via ssh on your local machine

```sh
ssh root@<your_ip_address>
```

### Setting up the keyboard layout <a name="setting-up-the-keyboard-layout"></a>

Use the grep command to find your keyboard layout

```sh
localectl list-keymaps | grep <your_language_code>
```

Apply keyboard settings

```sh
loadkeys <language_code>
```

### Connect to the Internet <a name="connect-to-the-internet"></a>

This should work in the VM just like connecting an ethernet cable to your computer.

Check that you are connected to the Internet.

```sh
ip a
```

To connect to WiFi:

```sh
iwctl
```

And use steps: `device list` -> `station <device> scan` -> `station <device> get-networks` -> `station <device> connect <Network_name>` -> `exit`.

If you are using ethernet or the VM, make sure your device is listed.

```sh
ip link
```

### Update the system clock <a name="update-the-system-clock"></a>

Clock should be synced automatically, to check the status of the system clock

```sh
timedatectl
```

## 💾 Partitioning <a name="---partitioning"></a>

You can check what type of boot mode is in your system:

```sh
cat /sys/firmware/efi/fw_platform_size
```

If the file exists you are on UEFI, if not you are on BIOS.

### Creating and formatting partitions <a name="creating-and-formatting-partitions"></a>

The easiest way to partition the harddisk is to use `cfdisk`. On the VM the BIOS is used and there won't be any instructions on how to create a UEFI partition in this guide. Create two partitions, one for BIOS, 100MB is more than enough, and the rest for the Linux filesystem.

```sh
cfdisk /dev/<disk>
```

Format the Linux partition as BTRFS and add a larger node size for metadata (default 16k max 64k). Higher node sizes give better packing and less fragmentation at the cost of more expensive memory operations while updating the metadata blocks.

```sh
mkfs.btrfs -f -L <your_label> -n 32k /dev/<linux_partition>
```

### Creating subvolumes <a name="creating-subvolumes"></a>

The only way to add new subvolumes is to go into recovery mode and repeat the following steps as root. It is necessary to remount partinion to the `/mnt` like below. Another option is to use the live ISO.

Mount the Linux partition:

```sh
mount /dev/<linux_patrition> /mnt
```

Create BTRFS subvolumes, the `su cr` command is an abbreviation of `su`bvolume `cr`eate. The following subvolumes are required for snapper and the system to work properly, and to reduce snapshot slowdowns (pacman, tmp)

```sh
btrfs su cr /mnt/@;
btrfs su cr /mnt/@home;
btrfs su cr /mnt/@snapshots;
btrfs su cr /mnt/@log;
btrfs su cr /mnt/@swap;
btrfs su cr /mnt/@pacman;
btrfs su cr /mnt/@tmp
```

Now unmount `/mnt` and remount the Linux partition with below settings

```sh
umount /mnt;
mount -o noatime,compress=lzo,space_cache=v2,subvol=@ /dev/vda2 /mnt
```

More about selected options can be found here: [link](https://btrfs.readthedocs.io/en/latest/ch-mount-options.html)
| Option | desc |
| ------ | ------ |
| noatime | Significantly improves performance because no new access time information needs to be written. Default option here is `relatime`, but it is not working well with BTRFS! Read more in [here](https://lwn.net/Articles/499293/) |
| compress | Control BTRFS file data compression. Type may be specified as zlib, lzo, zstd or no. More in here: [link](https://btrfs.readthedocs.io/en/latest/Compression.html) |
| space_cache | The free space cache greatly improves performance when reading block group free space into memory. V2 is newer better version. But it is good to make sure to have it is set. |
| subvol | Subvolume path |

Create folders for home, snopshots, swap and other subvolumes

```sh
mkdir -p /mnt/{home,var/log,var/tmp,var/cache/pacman/pkg,.snapshots,swap}
```

and mount subvolumes

```sh
mount -o noatime,compress=lzo,space_cache=v2,subvol=@home /dev/vda2 /mnt/home;
mount -o noatime,compress=lzo,space_cache=v2,subvol=@log /dev/vda2 /mnt/var/log;
mount -o noatime,compress=lzo,space_cache=v2,subvol=@tmp /dev/vda2 /mnt/var/tmp;
mount -o noatime,compress=lzo,space_cache=v2,subvol=@pacman /dev/vda2 /mnt/var/cache/pacman/pkg;
mount -o noatime,compress=lzo,space_cache=v2,subvol=@snapshots /dev/vda2 /mnt/.snapshots
```

## 💿 System installation <a name="---system-installation"></a>

### Setting up mirrors for faster downloads <a name="setting-up-mirrors-for-faster-downloads"></a>

This can speed up our download time and help prevent timeouts. Select the HTTPS mirrors that have been synchronised within the last 12 hours and are located in either `Country1` and `Country2`, sort them by download speed, and overwrite the `/etc/pacman.d/mirrorlist` file with the results

```sh
reflector --country <Country1>,<Country2> --protocol https --age 12 --sort rate --save /etc/pacman.d/mirrorlist
```

### Install base system and libraries <a name="install-base-system-and-libraries"></a>

```sh
pacstrap -K /mnt base base-devel btrfs-progs git grub grub-btrfs inotify-tools linux linux-firmware linux-headers man neovim networkmanager openssh reflector snapper sudo
```

### Generate fstab file <a name="generate-fstab-file"></a>

```sh
genfstab -U /mnt >> /mnt/etc/fstab
```

## ⌨️ Chroot <a name="---chroot"></a>

```sh
arch-chroot /mnt
```

### Set the date and time <a name="set-the-date-and-time"></a>

To find your time zone

```sh
timedatectl list-timezones | grep <country>
```

```sh
ln -sf /usr/share/zoneinfo/<Region/City> /etc/localtime
```

Set the hardware clock

```sh
hwclock --systohc
```

### Set locale <a name="set-locale"></a>

Uncomment your locale in `/etc/locale.gen` and save the changes.
Generate the locale and add a new line with your locale to `/etc/locale.conf`

```sh
locale-gen;
echo LANG=<locale> > /etc/locale.conf
```

Set up your keymap

```sh
echo "KEYMAP=<keymap>" > /etc/vconsole.conf
```

### Set hostname and hosts <a name="set-hostname-and-hosts"></a>

```sh
my_hostname=<hostname>;
echo $my_hostname >> /etc/hostname;
echo "127.0.0.1   localhost"$'\n'"127.0.1.1   $my_hostname.localdomain $my_hostname"$'\n'"::1         localhost" >> /etc/hosts
```

### Set root password and create user <a name="set-root-password-and-create-user"></a>

```sh
my_username=<username>;
passwd;
useradd -m -g users -G wheel $my_username;
passwd $my_username
```

Use the following command and uncomment the line `%wheel ALL=(ALL) ALL` line to enable `sudo`

```sh
EDITOR=nvim visudo
```

### Enable network manager and ssh services <a name="enable-network-manager-and-ssh-services"></a>

```sh
systemctl enable NetworkManager;
systemctl enable sshd
```

### Create and enable swapfile <a name="create-and-enable-swapfile"></a>

The default swap size is 2GB if, `--size` option is not set. Swapfile is reccomended option on BTRFS partinion.
Instructions how to enable swap on BTRFS are here: [link](https://wiki.archlinux.org/title/Btrfs#Swap_file)

> :warning: - Swapfile needs to be mounted as subvolume, otherwise `Snapper` won't work. There can be error like `Cannot create snapshot`.

```sh
swap_size=2;
sudo mount -o subvol=@swap /dev/vda2 /swap;
btrfs filesystem mkswapfile --size "$swap_size"g --uuid clear /swap/swapfile;
swapon /swap/swapfile
```

Edit `fstab` and add swapfile entry.

```sh
nvim /etc/fstab
```

`/swap/swapfile none swap defaults 0 0`

### Installing and configuring the GRUB boot loader <a name="installing-and-configuring-the-grub-boot-loader"></a>

Here give the path to your hard disk volume, not the partition where you want to install GRUB.

```sh
grub-install /dev/<disk>;
grub-mkconfig -o /boot/grub/grub.cfg
exit
```

Unmount `/mnt` and reboot the system.

```sh
umount -R /mnt
reboot
```


## Configure snapper <a name="configure-snapper"></a>

More information at point `5.3.1` on https://wiki.archlinux.org/title/Snapper

List your btrfs subvolumes with command

```sh
sudo btrfs sub list /
```

```sh
sudo umount /.snapshots;
sudo rm -r /.snapshots;
sudo snapper -c root create-config /
```

Above command creates another subvolume /.snapshots that we do not need. Delete this subvolume, create subvolume folder if not exists and mount subvolume:

```sh
sudo btrfs sub del /.snapshots/;
sudo mkdir /.snapshots;
sudo mount -o subvol=@snapshots /dev/<linux_filesystem> /.snapshots
```

Verify if snapshots subvolume is now in `/etc/fstab`. Mount all subvolumes and give 750 permissions to `.snapshots` folder

```sh
sudo mount -a;
sudo chmod 750 /.snapshots
```

### Snapper configuration <a name="snapper-configuration"></a>

Configuration files for Snapper are in `/etc/snapper/configs/root` file. To use it as a sudo user there is need to add user and group to configuration file.

```sh
nvim /etc/snapper/configs/root
```

Add user and group to be able to use Snapper as user not root:

```
ALLOW_USERS="my_username"
ALLOW_GROUPS="wheel"
```

By default `Snapper` is creating scheduled hourly snapshots. This is not working until we not install and enable `cronie`:

```sh
sudo pacman -S --needed cronie;
systemctl enable cronie.service
```

If you do not want cronie you can use enable below(optional):
```sh
sudo systemctl enable --now snapper-timeline.timer
sudo systemctl enable --now snapper-cleanup.timer
```

If you do not want to schedule snapshots hourly, this can be disabled by setting below to `no`:

```
TIMELINE_CREATE="no"
```

If above option is set `yes`, `Snapper` keeping 10 horly, dayly, mounthly and yearly. This can be limited in options like so:

```
TIMELINE_MIN_AGE="1800"
TIMELINE_LIMIT_HOURLY="5"
TIMELINE_LIMIT_DAILY="7"
TIMELINE_LIMIT_WEEKLY="0"
TIMELINE_LIMIT_MONTHLY="3"
TIMELINE_LIMIT_YEARLY="5"
```

To manually create snapshots use command:

```sh
snapper create --description "my_snapshot_name"
```

### Restore snapshots from GRUB menu <a name="restore-snapshots-from-grub-menu"></a>

To enable snapshot restoration from GRUB install `grub-btrfs` package (done in previous steps). More info about Snapper configuration and [grub-btrfs](https://github.com/Antynea/grub-btrfs).

To manually generate GRUB snapshot entries you can run:

```sh
sudo /etc/grub.d/41_snapshots-btrfs
```

To enable auto refresh list of sanpshots in GRUB menu enable `grub-btrfsd` service

```sh
sudo systemctl enable grub-btrfsd
```

Update GRUB to apply changes.

```sh
grub-mkconfig -o /boot/grub/grub.cfg
```

### Fix restore read only snapshots from GRUB <a name="fix-restore-read-only-snapshots-from-grub"></a>

Instructions for Arch: https://github.com/Antynea/grub-btrfs/blob/master/initramfs/readme.md

```sh
git clone https://github.com/Antynea/grub-btrfs.git;
sudo cp grub-btrfs/initramfs/Arch\ Linux/overlay_snap_ro-install /etc/initcpio/install/grub-btrfs-overlayfs;
sudo cp grub-btrfs/initramfs/Arch\ Linux/overlay_snap_ro-hook /etc/initcpio/hooks/grub-btrfs-overlayfs;
rm -rdf grub-btrfs
```

Edit `/etc/mkinitcpio.conf` file and add `grub-btrfs-overlayfs` at the end of the line `HOOKS=(... grub-btrfs-overlayfs)`.

```sh
sudo nvim /etc/mkinitcpio.conf
```

Regenerate `mkinitcpio`

```sh
sudo mkinitcpio -P
```

### Auto create snapshots before and after running Pacman <a name="auto-create-snapshots-before-and-after-running-pacman"></a>

For more details check: [snap-pac](https://github.com/wesbarnett/snap-pac)

```sh
sudo pacman -S snap-pac
```

## ⚙️ Post installation steps <a name="---post-installation-steps"></a>

Log in to the system using the credentials provided in the installation steps. 
If you need to connect to the WiFi, you can use: `nmtui`.

### Install desktop environment <a name="install-desktop-environment"></a>

Install CPU driver, sound driver, printers, etc

```sh
sudo pacman -S cups hplip intel-ucode pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber;
sudo systemctl enable cups
```

Install KDE Plasma and kscreen for screen management.

```sh
sudo pacman -S plasma-desktop kscreen
```
### Install browser and terminal <a name="install-browser-and-terminal"></a>

```sh
sudo pacman -S firefox kitty
```

### Install graphic card drivers for intel dedicated graphics <a name="install-graphic-card-drivers-for-intel-dedicated-graphics"></a>

```sh
sudo pacman -S xf86-video-intel
```

### Install SDDM <a name="install-sddm"></a>

Display managers are useful if you have multiple DE's or WM's and want to choose where to boot from in a GUI fashion They also they take care of the launch process.

```sh
sudo pacman -S sddm
```

Enable SDDM service to make it start on boot.

```sh
sudo systemctl enable sddm
```

For KDE install this to control the SDDM configuration from the KDE settings App.

```sh
sudo pacman -S --needed sddm-kcm
```
