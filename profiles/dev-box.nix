{ ... }:
{
  imports = [
    ../modules/base.nix
    ../modules/docker.nix
    ../modules/tailscale.nix
  ];

  rpi.docker.enable = true;
  rpi.tailscale.enable = true;
}
