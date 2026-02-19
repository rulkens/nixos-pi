{ ... }:
{
  imports = [
    ../modules/base.nix
    ../modules/docker.nix
    ../modules/tailscale.nix
    ../modules/samba.nix
  ];

  rpi.docker.enable = true;
  rpi.tailscale.enable = true;
  rpi.samba.enable = true;
}
