# Post installation steps

Steps after installing the base system. This includes optional desktop environment and all the drivers required for system functioning properly and also all basic programs, fonts, security, etc.
First log in to the system using the credentials provided in the installation steps.
If you need to connect to the WiFi, you can use: `nmtui`.

## Table of contents

- [Configuration](#configuration)
  - [Pacman configuration](#pacman-configuration)
  - [Upgrade the system](#upgrade-system)
- [Security](#security)
  - [Firewall](#firewall)
- [Drivers](#drivers)
  - [CPU drivers](#cpu-drivers)
  - [Graphics drivers](#graphics-drivers)
  - [Sound drivers](#sound-drivers)
  - [Bluetooth drivers](#bluetooth)
  - [Printers support](#printers-support)
  - [Input devices drivers](#input-devices-drivers)
- [Graphical desktop setup](#graphical-desktop-setup)
  - [Desktop environment](#desktop-environment)
  - [Desktop manager](#desktop-manager)
  - [Desktop software](#desktop-software)
  - [Fonts](#fonts)

## 🔧 Configuration <a name="configuration"></a>

### Pacman configuration <a name="pacman-configuration"></a>

Pacman configuration files can be found in `/etc/pacman.conf`:

```sh
sudo nvim /etc/pacman.conf
```

We can do a few things here:

- add more colors to the Pacmam TUI by uncommenting `Color`
- speedup downloads by adding more parallel with option `ParallelDownloads` set to some value
- make Pacman eating candies while installing software add `ILoveCandy`
- enable `multilib` repository that contains 32-bit software and libraries (wine, steam), just uncomment below **2 lines** and upgrade system after that
  ```
  [multilib]
  Include = /etc/pacman.d/mirrorlist
  ```

### Upgrade the system <a name="upgrade-system"></a>

Before installing further software and drivers it is recommended to upgrade the system. Do it also after enabling `multilib` repository.

```sh
sudo pacman -Syu
```

## 🔒 Security <a name="security"></a>

### Firewall <a name="firewall"></a>

The simplest and most popular firewall is `ufw`. Below is the basic installation with pacman and setup. First it is good to stop `ufw` before configuration or make sure that it is not running. This is basic setup allowing only SSH and HTTP ports to be accessed from outside.

Install UFW with command:

```sh
sudo pacman -S ufw
```

Example configuration, here everything is blocked except ports 22, 80 443:

```sh
sudo systemctl stop ufw;
sudo ufw default deny incoming;
sudo ufw default allow outgoing;
sudo ufw allow ssh;
sudo ufw allow http;
sudo ufw allow https

```

Start and enable UFW:

```sh
sudo systemctl start ufw;
sudo ufw enable
```

## 💾 Drivers

### CPU drivers <a name="#cpu-drivers"></a>

Install your CPU drivers, but first check CPU info with command:

```sh
lscpu
```

More about microcode CPU drivers can be found in this [wiki](https://wiki.archlinux.org/title/Microcode). Depends on your CPU manufacturer install `amd-ucode` or `intel-ucode` package like below:

```sh
sudo pacman -S intel-ucode
```

Additionally, for CPU frequency scaling read [this](https://wiki.archlinux.org/title/CPU_frequency_scaling) wiki page.

### Graphics drivers <a name="#graphics-drivers"></a>

For the graphics drivers installation follow this [wiki](https://wiki.archlinux.org/title/Xorg#Driver_installation). Alternatively install your drivers from producer website.

First you can enable 32-bit software and libraries by enabling multilib:

```sh
nvim /etc/pacman.conf
```

Here uncomment two lines:

```
[multilib]
Include = /etc/pacman.d/mirrorlist
```

If you follow xorg Arch installation steps wiki first run:

```sh
sudo pacman -S xorg-server
```

And then install your drivers. In below example drivers for Intel integrated graphic card.

```sh
sudo pacman -S xf86-video-intel
```

To check GPU info run:

```sh
lspci -k | grep -A 2 -E "(VGA|3D)"
```

### Sound drivers <a name="sound-drivers"></a>

Again the best info about installation options and steps can be found on Arch wiki page [here](https://wiki.archlinux.org/title/Sound_system).
Below is an example installation of all sound drivers.

Install default Linux kernel component providing low level support for audio hardware:

```sh
sudo pacman -S alsa-utils
```

Most common Linux drivers are PipeWire and PulseAudio:

```sh
sudo pacman -S pipewire pipewire-alsa pipewire-jack pipewire-pulse wireplumber
```

### Bluetooth drivers <a name="bluetooth"></a>

Install basic Bluetooth drivers:

```sh
sudo pacman -S bluez blueman bluez-utills;
sudo modprobe btusb
```

Enable Bluetooth:

```sh
sudo systemctl enable bluetooth;
sudo systemctl start bluetooth
```

### Install printers support <a name="printers-support"></a>

Install cups and HP driver and print manager:

```sh
sudo pacman -S cups hplip print-manager

```

After that enable printer in `systemctl` and add user to group `lpadmin`

```sh
sudo systemctl enable cups;
sudo usermod -a -G lpadmin $username
```

### Input devices drivers <a name="input-devices-drivers"></a>

To add support for input devices like mouse acceleration, additional buttons, touchpad or touchscreen you need to install additional drivers.

Example touchpad driver can be added by:

```sh
sudo pacman -S xf86-input-synaptics
```

## 🖥️ Graphical desktop setup <a name="graphical-desktop-setup"></a>

### Desktop environment <a name="desktop-environment"></a>

Install KDE Plasma and kscreen for screen management.

```sh
sudo pacman -S plasma-desktop kscreen
```

### Desktop manager <a name="desktop-manager"></a>

Display managers are useful if you have multiple DE's or WM's and want to choose where to boot from in a GUI fashion They also they take care of the launch process.
More about display managers [here](https://wiki.archlinux.org/title/SDDM)

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

### Desktop software <a name="desktop-software"></a>

This is according to your needs :)

### Fonts <a name="fonts"></a>

Remember to add system fonts like MacOS or Windows fonts if you are editing or using files created there.
