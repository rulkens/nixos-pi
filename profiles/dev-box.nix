{ ... }:
{
  imports = [
    ../modules/base.nix
    ../modules/docker.nix
    ../modules/tailscale.nix
    ../modules/samba.nix
    ../modules/mosquitto.nix
  ];

  rpi.docker.enable = false;
  rpi.tailscale.enable = false;
  rpi.samba.enable = true;
  rpi.mosquitto.enable = true;
}
