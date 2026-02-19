{ ... }:
{
  imports = [
    ../modules/base.nix
    ../modules/docker.nix
    ../modules/tailscale.nix
    ../modules/samba.nix
    ../modules/mosquitto.nix
    ../modules/headless-gl.nix
  ];

  rpi.docker.enable = false;
  rpi.tailscale.enable = false;
  rpi.samba.enable = true;
  rpi.mosquitto.enable = true;
  rpi.headlessGL.enable = true;
}
