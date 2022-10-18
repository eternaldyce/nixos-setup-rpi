
# Config for rpi4B. Boots from M.2 SATA instead of SD card. Formatting: 
# ZFS; Luks for full disk encryption, rather than ZFS's encryption.
#
# Installation adapted from: 
# <https://gist.github.com/martijnvermaat/76f2e24d0239470dd71050358b4d5134> 
# <https://mgdm.net/weblog/nixos-on-raspberry-pi-4/>
#
# TODO:
#
# [] idr if I checked against <https://nixos.wiki/wiki/ZFS> when 
#    building this. If I run out of space, could cause problems.
# [] headless! currently requires password entry on boot
# [] find out if `hardware.enableRedistributableFirmware = true;` is req.
# [] archivebox is broken
# [] zimwriterfs is incompatable w/ aarch64 
# [] auto-mount TV, Movies, archive, etc.
# [] script for auto-starting kiwix
# [] import httrack sites
# [] auto-start httrack sites
# [] boot fails when SD card is inserted -> config w/ rpiOS
# [] borg backups, auto borg backups
# [] finish binary cache
# [] landing page
# [] find indexer compatable w/ aarch64

{ config, pkgs, ... }:

{
  imports =
    [
      <nixos-hardware/raspberry-pi/4> # see note on imports
      ./hardware-configuration.nix
    ];
# imports: note that in order for this configuration file to work, 
# another channel has to be added to `nix-channel` to provide 
# raspberry-pi-specific kernels. The method described in the guides is 
# deprecated.
#
# To add rpi4 (depricated):
# $ sudo nix-channel --add https://github.com/NixOS/nixos-hardware/archive/master.tar.gz nixos-hardware
# $ sudo nix-channel --update

  boot.loader.generic-extlinux-compatible.enable = false; # Enables the 
  # generation of /boot/extlinux/extlinux.conf
  
  boot = { 
     kernelPackages = pkgs.linuxPackages_rpi4;
     kernelParams = [
      "8250.nr_uarts=1"
      "console=ttyAMA0,115200"
      "console=tty1"
      "cma=128M"
     ];
  };
# Kernel parameters supposedly enable serial communication between the 
# rpi and a pc. Haven't tested it.

# Nixos doesn't recognize full disk encryption unless explicitly told
  boot.initrd.luks.devices.luksroot = { 
     device="/dev/disk/by-uuid/<redacted>"; 
     preLVM =true; 
     allowDiscards =true;
  };

  boot.loader.raspberryPi= {
      enable=true;
      version=4;
  };

  hardware.enableRedistributableFirmware = true;

# Allow unfree packages
  nixpkgs.config = {
     allowUnfree=true;
  };

# For networking, only one of wpa_supplicant or networkingmanager may be 
# enabled at the same time. 
  networking.hostName = "<redacted>"; 
  networking.hostId = "<redacted>"; # ZFS requirement
  networking.networkmanager.enable = true; # Enables wireless
  # HostId: cached in mind as a requirement for enabling ssh with ZFS, 
  # but I can't remember where I read that.

  time.timeZone = "<redacted>";

# The global useDHCP flag is deprecated, therefore explicitly set to 
# false here. Per-interface useDHCP will be mandatory in the future, so 
# this generated config replicates the default behaviour.
  networking.useDHCP = false;
  networking.interfaces.eth0.useDHCP = true;
  networking.interfaces.wlan0.useDHCP = true;

  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  services.xserver ={
      enable = true;
      displayManager.lightdm.enable = true;
      desktopManager.xfce.enable = true;
  };

  sound.enable =true;
  hardware.pulseaudio.enable=true;

  users.users.<username>= {
      isNormalUser= true;
      hashedPassword="<redacted>";
      extraGroups = ["wheel"];
   };

  users.users.archive = { # user account for media server/archiving
      isSystemUser= true;
      createHome = true; # media library goes here
      group = "media";
      password = "<redacted>";
     };

  nixpkgs.config.permittedInsecurePackages = [
               # "python3.9-django-3.1.14" # for archivebox - broken
              ];  

  environment.systemPackages = with pkgs; [
      acl
      appimage-run
      aria2
      # archivebox # - broken
      audacity
      # authy # - unavailable for aarch64
      bandwidth 
      binutils
      # bisq-desktop # - unavailable for aarch64
      borgbackup
      busybox
      calcurse
      calibre
      calibre-web
      cheat
      cht-sh
      chromium
      cmus
      coreutils
      cryptsetup
      csvkit
      curl
      duf
      detox
      dtrx
      electrum
      exfat
      firefox
      ffmpeg
      glow
      git-annex
      gitAndTools.gitFull
      gobby
      gparted
      gnupg
      gnuplot
      gramps
      grip
      htop
      httrack
      imagemagick
      imgp
      kiwix
      krita
      lftp
      libreoffice
      # lnav # fails to build
      man-pages
      matcha-gtk-theme
      mdbook
      monero-gui
      mpv
      mypaint
      # mullvad-vpn # unsupported on aarch64
      nmap # ncat
      ncdu
      nicotine-plus
      nix-du
      nix-index
      nix-tree
      nnn
      ntfs3g
      obsidian
      pandoc
      pass
      pastel
      qbittorrent
      ripgrep
      rmlint
      rsync
      # sublime3 - unsupported on aarch64
      sudo
      syncthing
      taskwarrior
      tcpdump
      thunderbird
      tldr
      tmux
      # tor-browser-bundle-bin # unsupported on aarch64
      usbutils
      wget
      youtube-dl
      yt-dlp
      zim
      # zimwriterfs # unsupported on aarch64-linux; search.nixos.org lies.
      zfs
      zlib
      zotero
      woof
      # wasabiwallet # - unsupported
      # wasabibackend # - unsupported
  ];

  ##  media library  ##
  # folders that multiple services need to touch are set to 770 or 775.
  
  services.sonarr = { # port: 8989
      enable = true;
      group = "media"; 
      # sonarr will break if user is set to anything but "sonarr". needs 
      # to touch: ["/home/archive/Downloads", "/home/archive/torrents", 
      # "/home/archive/tv/TV"]
  };
  services.radarr.enable = true; # :7878
  services.jackett.enable = true; # :9117
  services.prowlarr.enable = true; # :9696
      # prowlarr is currently linked to NZBgeek; if broke, check subscription
  services.transmission = { # port 9091
      enable = true;
      group = "media";
      user = "archive";
      openRPCPort = true;
      settings.rpc-bind-address = "0.0.0.0"; 
      settings.watch-dir-enabled = true;
      settings.download-dir = "/home/archive/Downloads";
      settings.watch-dir = "/home/archive/torrents";
      settings.rpc-whitelist = "127.0.0.1,192.168.8.105"; # <- not static
  };
  services.sabnzbd = { # :8080 -> 8089
      enable = true;
      group = "media";
      # additional configuration steps: possibly because it collides 
      # with calibre-server's port 8080. No option to change it from here. 
      # - start it manually from /../hash/sabnzbd 
      #   (info @ `systemctl status sabnzbd`) with command line parameters 
      #   `-s 0.0.0.0:8089` 
      # - do configuration wizard - copy sabnzbd ini from 
      #   home/$USER/.sabnzbd/sabnzbd.ini to /var/lib/sabnzbd... 
      # - change permissions of .ini to match perms in /var/lib/sabnzbd
      # note: completed downloads folder shld be set to 775 
  };
  services.jellyfin = { # :8096
      enable = true;
      group = "media";
      user = "archive";
  };
  services.bazarr = { # :6767
      enable = true;
   #   group = "media";
      openFirewall = true;
  };
  services.calibre-server.enable = true; # :8080
  services.calibre-server.user = "<redacted>";
  services.calibre-server.libraries = ["/home/<redacted>/books"]; 
     # temporary. should be moved to `/home/archive/books`  


  # utilities
  # services.grocy.enable = true;
  # services.grocy.hostName = "192.168.8.148:7879";  
  # services.grocy.nginx.enableSSL = false;
  services.syncthing.enable = true;

  # services.calibre-web = {
  #    enable = true;
  #    options.calibreLibrary = ["/home/<redacted>/books"];
  #    options.enableBookUploading = true;
  #    openFirewall = true;
  #    user = "<redacted>";
  # };  

  ## Binary Cache for Serving Nixos packages to local machines ##
  services.nix-serve = {
     enable = true;
     secretKeyFile = "/var/cache-priv-key.pem";
  };

  services.nginx = { 
    enable = true;
    virtualHosts = { 
      "192.168.1.148" = {
         serverAliases = [ "binarycache" ];
         locations."/".extraConfig = ''
           proxy_pass http://localhost:${toString config.services.nix-serve.por>
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
         '';
     };
    };
  };

  # search
  # services.meilisearch.enable = true; #unavailable on aarch64 rpi

  # Configure keymap in X11
  services.xserver.layout = "us";
  services.xserver.xkbOptions = "eurosign:e";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 5000 80 8096 7879]; 
      # 5000, 80 = binary cache
      # 8096 = jellyfin
      # 7879 = grocy
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.05"; # Did you read the comment?

}
