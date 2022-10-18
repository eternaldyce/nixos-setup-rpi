# nixos-setup-rpi

I typically use a NUC mini pc running nixOS to do some set of automated archiving tasks that i want to run 24/7, along with hosted services and other tasks. My NUC, which I've been using since 2018, uses a lot more power than a raspberry pi (approx 4.6x more, if i'm calculating it right.) So it was of interest to me to have a low-power version of my existing setup.

I wanted to continue using nixos, with full disk encryption, and ZFS. I use nixos for reasons that are hard to articulate, aside from saying that I like how I can define all the packages and services my machine will use in a configuration file, and the nixos machine will return the exact same machine to every time. There are some use cases where this is really convenient. 

For this machine, I'm using ZFS because it provides me with more tools to avoid data loss. I'm currently in the process of backing up data to bluray disks, but ZFS adds an additional layer of protection. 

I also didn't want to run my OS off of an SD card, since SD cards tend to wear out quickly when used as an OS, so I wanted to use a normal M2 sata. 

So for this project I'm using a raspberry pi 4 with a M.2 SATA external SSD reader, & a M.2 SATA internal SSD. 

Following these instructions should reproduce the OS and environment I'm using. This guide assumes you're familiar with using a terminal ever.

## Hardware
```
raspberry pi 4 model B ($60?)
M.2 SATA 500GB ($75)
M.2 SATA SSD to USB 3.0 external reader & enclosure($15)  https://www.amazon.com/gp/product/B076DCNZM3/
OR
Argon One M.2 case with expansion board ($70)  https://www.amazon.com/gp/product/B08MJ3CSW7
depending if you want an enclosure or not.

generic microSD card (single use, not going to be the OS so it can be 8GB or whatever)
screen 
keyboard
HDMI cable + converter
one of those tiny screwdrivers
power supply
file (if using the argon case, to shave off excess plastic on the usb connection between the m.2 and the pi.)
```

## Installing & Configuring the OS

see: https://gist.github.com/martijnvermaat/76f2e24d0239470dd71050358b4d5134
and: https://mgdm.net/weblog/nixos-on-raspberry-pi-4/

## put nixos on a microSD card and boot the device

First you want to take the microSD card and copy an image of nixos onto it, from the generic SD image. https://nixos.wiki/wiki/NixOS_on_ARM/Raspberry_Pi_4

The command to copy the image to the microSD card will look something like..

`# dd bs=1M if=your_image_file_name.img of=/dev/name-of-SD-card`

You can find the computer's name for your microSD card using a command like `lsblk` & for a microSD card it'll probably begin with the letters, "mmcblk."

Once that's done, put the microSD card in the rpi, plug in the m.2 sata, and attach any peripherals. Then boot it up.

## encrypt the M.2 SATA SSD and configure ZFS

Run `lsblk` and it should return two entries, your microSD card which is mounted, and a blank M.2 SATA SSD which the machine will probably call  "sda" or "sdb" depending on how many drives you have connected. From here we create the partition table on the M.2 SATA:

```
# parted /dev/sda -- mklabel msdos
# parted /dev/sda -- mkpart primary fat32 0MiB 512MiB # sda1 = /boot
# parted /dev/sda -- mkpart primary 512MiB 100% # sda2 = ZFS partition

# mkfs.vfat -F32 /dev/sda1 # format boot
```

I'm not encrypting boot because I have been under time constraints such that reading through whether the available boot loaders would be able to deal with an encrypted boot was one thing too many for me, and didn't seem worth it given that my sensitive data is stored on encrypted external drives. It's on my stack to put aside a few hours to figure it out sometime, but as of writing this I haven't, yet.

```
# cryptsetup luksFormat /dev/sda2
# cryptsetup luksOpen /dev/sda2 enc-pv
```

Those two commands will set up and mount the encrypted partition. Encrypted partitions can be found at `/dev/mapper` in this case, `/dev/mapper/enc-pv`

I guess I also could've created two logical volumes inside sda2, like 

```
# pvcreate /dev/mapper/enc-pv
# vgcreate vg /dev/mapper/enc-pv
# lvcreate -L 8G -n swap vg
# lvcreate -l '100%FREE' -n root vg
```

And then format the swap as

`# mkswap -L swap /dev/vg/swap`

I forget why I didn't. There was a big gap between when I did the research and wrote out instructions, to when I actually installed the thing. It might've been an oversight.

From here we format the partitions. If you're not using ZFS, you'd just format as ext4.

```
# zpool create -f -O mountpoint=none rpool  /dev/mapper/enc-pv
# zfs create -o mountpoint=legacy rpool/root
# zfs create -o mountpoint=legacy rpool/root/nixos
# zfs create -o mountpoint=legacy rpool/home
```

## connect wifi and configure nixos

Here the drives get mounted and folders are made: 

```
# mount -t zfs rpool/root/nixos /mnt
# mkdir /mnt/home
# mount -t zfs rpool/home /mnt/home
# mkdir /mnt/boot
# mount /dev/sda1 /mnt/boot
```

rpi4 needs firmware. The firmware needed is on the SD card. I am not going to be booting the SD card, so I wanted to copy/paste it over.

```
# mkdir /firmware
# mount /dev/mmcblk0p1 /firmware
# cp /firmware/* /mnt/boot
```

Here I tell nixos to auto-generate the hardware configuration file and a basic configuration file, though if I were to try to build the system from here, it would not build, because I need to manually go into the configuration file to inform nixos that it is dealing with an encrypted file system.

```
# nixos-generate-config --root /mnt
```

At this point I need internet, so I configure some.

```
# wpa_supplicant -B -i wlan0 -c <(wpa_passphrase 'SSID' 'passphrase') &
```

So that I can download a bunch of rpi specific hardware configuration, and then add that to the configuration file, so it knows to build nixos with it.

```
# sudo nix-channel --add https://github.com/NixOS/nixos-hardware/archive/master.tar.gz nixos-hardware
# sudo nix-channel --update
```

Note: this is deprecated, apparently.

## Configuration

```
{ config, pkgs, ... }:

{
  imports =
	[
	  <nixos-hardware/raspberry-pi/4>
	  ./hardware-configuration.nix
	];

  boot = {
	kernelPackages = pkgs.linuxPackages_rpi4;
	kernelParams = [
	  "8250.nr_uarts=1"
	  "console=ttyAMA0,115200"
	  "console=tty1"
	  "cma=128M"
	];
  };


  # this is an encrypted system
  boot.initrd.luks.devices.luksroot = { 
     device = "/dev/disk/by-uuid/<yours here>"; 
     preLVM = true; allowDiscards = true; 
  }; #use blkid 2 get uuid

  boot.loader.raspberryPi = {
	enable = true;
	version = 4;
  };
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  hardware.enableRedistributableFirmware = true;
  nixpkgs.config = {
	allowUnfree = true;
  };

  networking.hostName = "<yours here>"; 
  networking.hostId = "<yours here>"; # ZFS

  networking.networkmanager.enable = true;
  ```

Run `# nixos-install`
	
Wait a long time. Once it's done, turn it off an remove the microSD card, then reboot it.
	
You'll also run
```
# sudo nix-channel --add https://github.com/NixOS/nixos-hardware/archive/master.tar.gz nixos-hardware
# sudo nix-channel --update
```

Again, because I added it to the version of nixos on the SD card, not the M2. SATA

