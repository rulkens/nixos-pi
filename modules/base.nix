# =========================================================
# NixOS Raspberry Pi 4 — Base System Configuration
# =========================================================
# This file defines everything about your Pi's system that
# is NOT personal or secret. The personal stuff (hostname,
# username, WiFi, SSH key) comes from local-config.nix.
#
# Think of this as the "template" for your Pi — it could
# be shared publicly or used by multiple people.
# =========================================================

{
  config,
  pkgs,
  lib,
  ...
}:

{
  # mDNS is enabled by default in the base config so you can reach the Pi
  # as <hostname>.local without knowing its IP address. This is especially
  # useful for headless setups where there's no screen to check the IP.
  # Disable with rpi.services.avahi.enable = false; in your profile if not needed.
  rpi.services.avahi.enable = true;

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
  system.stateVersion = "25.05";

  # ---------------------------------------------------------
  # Hardware
  # ---------------------------------------------------------
  # Enable GPU firmware for the Pi's VideoCore GPU.
  # Even headless, some system functions depend on this.
  hardware.enableRedistributableFirmware = true;

}
