# Arch Linux + snapshots + KDE Plasma test on VM

## 🔎 Description

Instructions for installing and configuring a Linux system based on Arch Linux with snapshot functionality.
System uses required BTRFS partitions, Snapper for snapshots and KDE Plasma desktop. This setup is used for testing on a VM machine.
These instructions are based on Arch wiki and [installanion guide](https://wiki.archlinux.org/title/Installation_guide).
All was tested with `Qemu` virtual manager and `archlinux-2024.11.01` ISO.

The goal is to have a "bleeding edge" system as the main home desktop environment, and to be able to have the latest packages for testing, while being backed up by snapshots and able to quickly restore the system after failed updates, upgrades or critical changes.

If you want a more stable, out of the box and easy to setup solution that does not require you to spend your whole life for setting up, use the [openSUSE Tumbleweed](https://get.opensuse.org/tumbleweed/). A very similar result can be achieved with this distribution, BTRFS partitions and snapshots can be set up with a simple UI installer and almost everything works out of the box after installation. Note that this not really contains all the latest software in this distro compared to Arch, as they aim to be more stable, describing themselves as `Leading-Edge` -> frequent updates plus stability.

## ✍🏼Collaboration

This is my discovery attempt to create such a system setup. Please contact me or create an `issue` if you have better suggestions or find bugs.

## ✨ Features

- Create and restore system snapshots using [Snapper](https://github.com/openSUSE/snapper)
- BTRFS system partition - required for system snapshots
- Create automatic snapshots before and after system and software updates with [snap-pac](https://github.com/wesbarnett/snap-pac)
- Restore the system from the boot menu with [grub-btrfs](https://github.com/Antynea/grub-btrfs)
- Desktop Environment - [KDE Plasma](https://kde.org/plasma-desktop/)
- SWAP working with BTRFS and snapshots

## Table of contents

- [Installation setup](#----installation-setup)
  - [SSH connection](#ssh-connection)
  - [Setting up the keyboard layout](#setting-up-the-keyboard-layout)
  - [Connect to the Internet](#connect-to-the-internet)
  - [Update the system clock](#update-the-system-clock)
- [Partitioning](#---partitioning)
  - [Creating and formatting partitions](#creating-and-formatting-partitions)
  - [Creating subvolumes](#creating-subvolumes)
- [System installation](#---system-installation)
  - [Setting up mirrors for faster downloads](#setting-up-mirrors-for-faster-downloads)
  - [Install base system and libraries](#install-base-system-and-libraries)
  - [Generate fstab file](#generate-fstab-file)
- [Chroot](#---chroot)
  - [Set the date and time](#set-the-date-and-time)
  - [Set locale](#set-locale)
  - [Set hostname and hosts](#set-hostname-and-hosts)
  - [Set root password and create user](#set-root-password-and-create-user)
  - [Enable network manager and ssh services](#enable-network-manager-and-ssh-services)
  - [Create and enable swapfile](#create-and-enable-swapfile)
  - [Installing and configuring the GRUB boot loader](#installing-and-configuring-the-grub-boot-loader)
- [Snapper configuration](#configure-snapper)
  - [Snapper setup](#snapper-configuration)
  - [Restore snapshots from grub menu](#restore-snapshots-from-grub-menu)
  - [Fix restore read only snapshots from GRUB](#fix-restore-read-only-snapshots-from-grub)
  - [Auto create snapshots before and after running pacman](#auto-create-snapshots-before-and-after-running-pacman)
- [Post installation steps](#---post-installation-steps)

## 🛠️ Installation setup <a name="----installation-setup"></a>

### SSH connection <a name="#ssh-connection"></a>

If the device and VM are connected to the same Internet, which is usually the case with Virtual Manager installed on the local computer, it is easy to connect via SSH and use the local computer's terminal to install Arch. This is a more convenient option. It is easier to change the font size, scroll through the terminal window to see older commands and output.

First install ssh on the VM Arch installation, enable the ssh service and set the ISO root password for security.

```sh
pacman -Sy --needed openssh;
systemctl enable sshd;
passwd
```

Check IP address on the VM to connect on local machine

```sh
ip address
```

Now connect via ssh on your local machine

```sh
ssh root@<your_ip_address>
```

### Setting up the keyboard layout <a name="setting-up-the-keyboard-layout"></a>

Use the grep command to find your keyboard layout typing your language code

```sh
localectl list-keymaps | grep <your_language_code>
```

Apply keyboard settings with command

```sh
loadkeys <language_code>
```

### Connect to the Internet <a name="connect-to-the-internet"></a>

> This step is not required in the VM, this should just work as machine connected through the Ethernet cable.

To connect to WiFi:

```sh
iwctl
```

And use steps: `device list` -> `station <device> scan` -> `station <device> get-networks` -> `station <device> connect <Network_name>` -> `exit`.

### Update the system clock <a name="update-the-system-clock"></a>

Clock should be synced automatically. To check the status of the system clock run:

```sh
timedatectl
```

## 💾 Partitioning <a name="---partitioning"></a>

First if you are not sure you can check what type of boot mode is in your system. Run below command. If the file exists you are on UEFI, if not you are on BIOS.

```sh
cat /sys/firmware/efi/fw_platform_size
```

### Creating and formatting partitions <a name="creating-and-formatting-partitions"></a>

The easiest way to partition the hard disk is to use `cfdisk`. VM is probably using BIOS, so here won't be any instructions on how to create a UEFI partition in this guide (for now). Create two partitions, one for BIOS, 100MB is more than enough, and the rest for the Linux filesystem.

```sh
cfdisk /dev/<disk>
```

Format the Linux partition as BTRFS and add a larger node size for metadata (default 16k max 64k). Higher node sizes give better packing and less fragmentation at the cost of more expensive memory operations while updating the metadata blocks.

```sh
mkfs.btrfs -f -L <your_label> -n 32k /dev/<linux_partition>
```

### Creating subvolumes <a name="creating-subvolumes"></a>

> :warning: - The only way to add new subvolumes later after this installation is to go into recovery mode and repeat the following steps as root. It is necessary to remount partition to the `/mnt` like below. Another option is to use the live ISO.

Mount the Linux partition:

```sh
mount /dev/<linux_patrition> /mnt
```

Create BTRFS subvolumes, the `su cr` command is an abbreviation of `su`bvolume `cr`eate. The following subvolumes are required for snapper and the system to work properly. @pacman and @tmp are to reduce snapshot creations slowdowns.

```sh
btrfs su cr /mnt/@;
btrfs su cr /mnt/@home;
btrfs su cr /mnt/@snapshots;
btrfs su cr /mnt/@log;
btrfs su cr /mnt/@pacman;
btrfs su cr /mnt/@tmp;
btrfs su cr /mnt/@swap
```

Now unmount `/mnt` and remount the Linux partition with below settings

```sh
umount /mnt;
mount -o noatime,compress=lzo,space_cache=v2,subvol=@ /dev/<linux_patrition> /mnt
```

More about selected options can be found here: [link](https://btrfs.readthedocs.io/en/latest/ch-mount-options.html).
| Option | desc |
| ------ | ------ |
| noatime | Significantly improves performance because no new access time information needs to be written. Default option here is `relatime`, but it is not working well with BTRFS! Read more in [here](https://lwn.net/Articles/499293/) |
| compress | Control BTRFS file data compression. Type may be specified as zlib, lzo, zstd or no. More in here: [link](https://btrfs.readthedocs.io/en/latest/Compression.html) |
| space_cache | The free space cache greatly improves performance when reading block group free space into memory. V2 is newer better version. But it is good to make sure to have it is set. |
| subvol | Subvolume path |

Create folders for home, snapshots, swap and other subvolumes...

```sh
mkdir -p /mnt/{home,var/log,var/tmp,var/cache/pacman/pkg,.snapshots,swap}
```

...and mount subvolumes

```sh
mount -o noatime,compress=lzo,space_cache=v2,subvol=@home /dev/<linux_partition> /mnt/home;
mount -o noatime,compress=lzo,space_cache=v2,subvol=@log /dev/<linux_partition> /mnt/var/log;
mount -o noatime,compress=lzo,space_cache=v2,subvol=@tmp /dev/<linux_partition> /mnt/var/tmp;
mount -o noatime,compress=lzo,space_cache=v2,subvol=@pacman /dev/<linux_partition> /mnt/var/cache/pacman/pkg;
mount -o noatime,compress=lzo,space_cache=v2,subvol=@snapshots /dev/<linux_partition> /mnt/.snapshots
```

## 💿 System installation <a name="---system-installation"></a>

### Setting up mirrors for faster downloads <a name="setting-up-mirrors-for-faster-downloads"></a>

This can speed up download time and help to prevent timeouts. Example below shows command to select the HTTPS mirrors that have been synchronised within the last 12 hours and are located in either `Country1` and `Country2`, sort them by download speed, and overwrite the `/etc/pacman.d/mirrorlist` file with the results.

```sh
reflector --country <Country1>,<Country2> --protocol https --age 12 --sort rate --save /etc/pacman.d/mirrorlist
```

### Install base system and libraries <a name="install-base-system-and-libraries"></a>

Here we are installing linux LTS kernel and other packages for system to work. To install latest linux change `linux-lts` to `linux` and `linux-headers`. It is also a good practice to have other kernel installed in case one we are using is not able to start after update. There is option to choose from kernels such as `linux-zen` or `linux-hardened`. You can also have them both and choose during system boot. In this step I am adding also `snapper` and `grub-btrfs`.

```sh
pacstrap -K /mnt base base-devel btrfs-progs git grub grub-btrfs inotify-tools linux-lts linux-lts-headers linux-firmware man neovim networkmanager openssh reflector snapper sudo
```

### Generate `fstab` file <a name="generate-fstab-file"></a>

```sh
genfstab -U /mnt >> /mnt/etc/fstab
```

## ⌨️ Chroot and final setup<a name="---chroot"></a>

```sh
arch-chroot /mnt
```

### Set the date and time <a name="set-the-date-and-time"></a>

To find your time zone run:

```sh
timedatectl list-timezones | grep <country>
```

```sh
ln -sf /usr/share/zoneinfo/<Region/City> /etc/localtime
```

Set the hardware clock with command:

```sh
hwclock --systohc
```

### Set locale <a name="set-locale"></a>

Uncomment your locale in `/etc/locale.gen` and save the changes.
Generate the locale and add a new line with your locale to `/etc/locale.conf`.

```sh
locale-gen;
echo LANG=<locale> > /etc/locale.conf
```

Set up your keymap settings.

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

Use the following command and uncomment the line `%wheel ALL=(ALL) ALL` line to enable `sudo`:

```sh
EDITOR=nvim visudo
```

### Enable network manager and ssh services <a name="enable-network-manager-and-ssh-services"></a>

```sh
systemctl enable NetworkManager;
systemctl enable sshd
```

### Create and enable swapfile <a name="create-and-enable-swapfile"></a>

> :warning: - Swapfile needs to be mounted as subvolume, otherwise `Snapper` won't work. There can be error like `Cannot create snapshot`.

Instructions how to enable swap on BTRFS are here: [link](https://wiki.archlinux.org/title/Btrfs#Swap_file).
I found it easier to make swap work with snapshots and BTRFS by creating swapfile manually rather than using the above instructions form the Arch wiki.
First, mount the `@swap` subvolume, create a swapfile inside the swap folder and give it `600` permissions. Use the `chattr` command to disable `copy on write` for this file. Set the size of the swap with the `dd` command where: if - input file, of - output, bs - block size and count is swap size. After that format swapfile and turn on swap.

> :warning: - Use `dd` to allocate swap space instead of `fallocate`, because it can create file-system holes, more info [here](https://askubuntu.com/questions/1017309/fallocate-vs-dd-for-swapfile).

```sh
swap_size=2048;
sudo mount -o subvol=@swap /dev/<linux_partition> /swap;
sudo touch /swap/swapfile;
sudo chmod 600 /swap/swapfile;
sudo chattr +C /swap/swapfile;
sudo dd if=/dev/zero of=/swap/swapfile bs=1024 count=$swap_size;
sudo mkswap /swap/swapfile;
sudo swapon /swap/swapfile
```

Edit `fstab` and add swapfile entries at the end of the file to make changes permanent. First defines that `/swap` folder is a separate subvolume and second defines swapfile.

```sh
echo 'UUID=<uudi_of_the_btrfs>  /swap  btrfs  subvol=/@swap  0  0' >> /etc/fstab;
echo '/swap/swapfile            none   swap   defaults       0  0' >> /etc/fstab
```

Verify the `/etc/fstab` file after all changes. SWAP should work now with correctly together with snapshots.

### Installing and configuring the GRUB boot loader <a name="installing-and-configuring-the-grub-boot-loader"></a>

> :warning: - Here give the path to your hard disk, not the partition volume where you want to install GRUB, e.g. instead of `vda2` use `vda`.

```sh
grub-install /dev/<disk>;
grub-mkconfig -o /boot/grub/grub.cfg;
exit
```

Unmount `/mnt` and reboot the system to finish the installation.

```sh
umount -R /mnt;
reboot
```

## Snapper configuration <a name="configure-snapper"></a>

To list your BTRFS subvolumes use command:

```sh
sudo btrfs sub list /
```

These steps are described on the Arch wiki page [here](https://wiki.archlinux.org/title/Snapper). To run `snapper` configuration first unmount snapshots volume and remove snapshots folder created before or make sure it is not there.

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

### Snapper setup <a name="snapper-setup"></a>

Configuration files for Snapper are in `/etc/snapper/configs/root` file. To use it as a sudo user there is need to add user and group to configuration file.

```sh
sudo nvim /etc/snapper/configs/root
```

Add user and group to be able to use Snapper as user not root:

```
ALLOW_USERS="my_username"
ALLOW_GROUPS="wheel"
```

By default `Snapper` is creating scheduled hourly snapshots. This is not working until we not install and enable `cronie`:

```sh
sudo pacman -S --needed cronie;
sudo systemctl enable cronie.service
```

If you do not want cronie you can use enable below (optional):

```
sudo systemctl enable --now snapper-timeline.timer
sudo systemctl enable --now snapper-cleanup.timer
```

If you do not want to schedule snapshots hourly, this can be disabled by setting below to `no`:

```
TIMELINE_CREATE="no"
```

If above option is set to `yes`, `Snapper` is keeping 10 hourly, daily, monthly and yearly snapshots. This can be limited in options e.g. like so:

```
TIMELINE_MIN_AGE="1800"
TIMELINE_LIMIT_HOURLY="5"
TIMELINE_LIMIT_DAILY="7"
TIMELINE_LIMIT_WEEKLY="0"
TIMELINE_LIMIT_MONTHLY="3"
TIMELINE_LIMIT_YEARLY="5"
```

To manually create snapshots use command with the description use:

```sh
snapper create --description "my_snapshot_name"
```

### Restore snapshots from GRUB menu <a name="restore-snapshots-from-grub-menu"></a>

To enable snapshot restoration from GRUB install `grub-btrfs` package (done in previous steps). More info about Snapper configuration here: [grub-btrfs](https://github.com/Antynea/grub-btrfs).

To manually generate GRUB snapshot entries you can run:

```sh
sudo /etc/grub.d/41_snapshots-btrfs
```

To enable auto refresh list of snapshots in GRUB menu enable `grub-btrfsd` service:

```sh
sudo systemctl enable grub-btrfsd
```

Update GRUB to apply all changes.

```sh
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

### Fix restore read only snapshots from GRUB <a name="fix-restore-read-only-snapshots-from-grub"></a>

There can be error about restoring read only snapshots on system boot from GRUB menu. Instructions to fix this for Arch are here: https://github.com/Antynea/grub-btrfs/blob/master/initramfs/readme.md .

```sh
git clone https://github.com/Antynea/grub-btrfs.git;
sudo cp grub-btrfs/initramfs/Arch\ Linux/overlay_snap_ro-install /etc/initcpio/install/grub-btrfs-overlayfs;
sudo cp grub-btrfs/initramfs/Arch\ Linux/overlay_snap_ro-hook /etc/initcpio/hooks/grub-btrfs-overlayfs;
rm -rdf grub-btrfs
```

Next edit `/etc/mkinitcpio.conf` file and add `grub-btrfs-overlayfs` at the end of the line `HOOKS=(... grub-btrfs-overlayfs)`.

```sh
sudo nvim /etc/mkinitcpio.conf
```

Regenerate `mkinitcpio`

```sh
sudo mkinitcpio -P
```

### Auto create snapshots before and after running Pacman <a name="auto-create-snapshots-before-and-after-running-pacman"></a>

Bleeding edge system can crash during updates. It is very handy to automatically create snapshot before installing updates. For more details check: [snap-pac](https://github.com/wesbarnett/snap-pac).

```sh
sudo pacman -S snap-pac
```

## ⚙️ Post installation steps <a name="---post-installation-steps"></a>

After installing the base system with working sanapshots, btrfs, swap it is time to install the desired software such as: desktop environment, display manager, drivers, base program and security enhancements. These steps depends on the user's preferences. My setup with KDE Plasma desktop can be found in this repository in a separate readme [here](POST_INSTALLATION.md) or installation script.
