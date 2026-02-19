{ ... }:
{
  imports = [
    ../modules/base.nix
    ../modules/docker.nix
    ../modules/tailscale.nix
    ../modules/samba.nix
    ../modules/mosquitto.nix
  ];

  rpi.docker.enable = true;
  rpi.tailscale.enable = true;
  rpi.samba.enable = true;
  rpi.mosquitto.enable = true;
}
