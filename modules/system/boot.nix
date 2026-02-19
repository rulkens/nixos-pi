{ pkgs, lib, ... }:
{
  # The Raspberry Pi doesn't use a traditional PC BIOS or UEFI to boot.
  # Instead, it uses its own bootloader on the GPU, which reads a boot
  # partition on the SD card. NixOS uses extlinux as a simple bootloader
  # that the Pi's firmware can chain-load.
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  # The Raspberry Pi optimized kernel includes all the right drivers
  # and device tree overlays for Pi hardware.
  boot.kernelPackages = pkgs.linuxPackages_rpi4;

  # The sd-image-aarch64 module tries to include kernel modules for many
  # different ARM boards (like sun4i-drm for Allwinner chips). The Pi 4
  # kernel doesn't have these, so we force the lists to only what the Pi
  # actually needs — otherwise the initrd builder fails on missing modules.
  boot.initrd.kernelModules = lib.mkForce [ ];
  boot.initrd.availableKernelModules = lib.mkForce [
    "usbhid"
    "usb_storage"
    "vc4"
    "pcie_brcmstb"
    "reset-raspberrypi"
  ];
}
