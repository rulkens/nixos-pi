# =========================================================
# NixOS Raspberry Pi 4 — System Configuration
# =========================================================
# This file defines everything about your Pi's system that
# is NOT personal or secret. The personal stuff (hostname,
# username, WiFi, SSH key) comes from local-config.nix.
#
# Think of this as the "template" for your Pi — it could
# be shared publicly or used by multiple people.
# =========================================================

{ config, pkgs, lib, ... }:

{
  # ---------------------------------------------------------
  # NixOS Version
  # ---------------------------------------------------------
  # This tells NixOS which version of the state format to
  # expect. It does NOT control which packages you get (that's
  # determined by the nixpkgs input in flake.nix). It exists
  # so that NixOS knows how to handle upgrades between
  # different versions — certain defaults may change between
  # releases, and this ensures backwards compatibility.
  # Set this to the version you first installed, and generally
  # don't change it.
  system.stateVersion = "24.11";

  # ---------------------------------------------------------
  # Boot Configuration
  # ---------------------------------------------------------
  # The Raspberry Pi doesn't use a traditional PC BIOS or
  # UEFI to boot. Instead, it uses its own bootloader on the
  # GPU, which reads a boot partition on the SD card.
  #
  # NixOS uses "extlinux" as a simple bootloader that the
  # Pi's firmware can chain-load. This is already configured
  # by the sd-image-aarch64 module, but we explicitly state
  # it here for clarity.
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  # The Linux kernel to use. We pick the Raspberry Pi
  # optimized kernel, which includes all the right drivers
  # and device tree overlays for Pi hardware.
  boot.kernelPackages = pkgs.linuxPackages_rpi4;

  # The sd-image-aarch64 module tries to include kernel modules
  # for many different ARM boards (like sun4i-drm for Allwinner
  # chips). The Pi 4 kernel doesn't have these, causing build
  # failures. Setting this to false tells the initrd builder
  # to skip modules it can't find instead of failing.
  boot.initrd.kernelModules = lib.mkForce [];
  boot.initrd.availableKernelModules = lib.mkForce [
    "usbhid"
    "usb_storage"
    "vc4"
    "pcie_brcmstb"
    "reset-raspberrypi"
  ];

  # ---------------------------------------------------------
  # Hardware
  # ---------------------------------------------------------
  # Enable GPU firmware for the Pi's VideoCore GPU.
  # Even headless, some system functions depend on this.
  hardware.enableRedistributableFirmware = true;

  # ---------------------------------------------------------
  # Networking
  # ---------------------------------------------------------
  # We use NetworkManager for network configuration. It's
  # more featureful than the alternatives and handles WiFi
  # well, including automatic reconnection.
  networking.networkmanager.enable = true;

  # Enable mDNS/DNS-SD via Avahi. This lets you find your
  # Pi on the local network as "<hostname>.local" instead
  # of having to look up its IP address. So if your hostname
  # is "rpi", you can do: ssh user@rpi.local
  services.avahi = {
    enable = true;
    nssmdns4 = true;   # Enable mDNS resolution for IPv4
    publish = {
      enable = true;
      addresses = true; # Publish our IP address
    };
  };

  # ---------------------------------------------------------
  # SSH Server
  # ---------------------------------------------------------
  # This is critical for headless operation — without SSH,
  # you'd need a monitor and keyboard to interact with the Pi.
  services.openssh = {
    enable = true;

    settings = {
      # Disable password authentication — only SSH keys allowed.
      # This is much more secure. If someone discovers your Pi
      # on the network, they can't brute-force a password.
      PasswordAuthentication = false;

      # Disable keyboard-interactive auth (another password method)
      KbdInteractiveAuthentication = false;

      # Don't allow root to log in via SSH. You'll log in as
      # your user and use sudo if you need root.
      PermitRootLogin = "no";
    };
  };

  # ---------------------------------------------------------
  # Firewall
  # ---------------------------------------------------------
  # NixOS enables a firewall by default. We need to make sure
  # SSH (port 22) is allowed through.
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

  # ---------------------------------------------------------
  # System Packages
  # ---------------------------------------------------------
  # These packages will be available system-wide for all users.
  # They're installed into the system profile, not per-user.
  environment.systemPackages = with pkgs; [
    vim           # Text editor
    git           # Version control
    htop          # Interactive process viewer
    curl          # HTTP client
    wget          # File downloader
    nodejs        # Node.js runtime
  ];

  # ---------------------------------------------------------
  # Locale & Timezone
  # ---------------------------------------------------------
  # Set a default timezone. Change this to your timezone.
  # Run `timedatectl list-timezones` to see all options.
  time.timeZone = "Europe/Amsterdam";

  # Default locale
  i18n.defaultLocale = "en_US.UTF-8";

  # ---------------------------------------------------------
  # Nix Settings
  # ---------------------------------------------------------
  # Enable flakes and the new nix command on the Pi itself,
  # so you can use `nix build`, `nix shell`, etc. when
  # logged in.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Automatic garbage collection to prevent the SD card from
  # filling up with old package versions.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
}
