{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./home
    ./services
    ./system
  ];

  # Tells NixOS which version of the state format to expect. This does NOT
  # control which packages you get — that is determined by the nixpkgs input
  # in flake.nix. Set this to the version you first installed and generally
  # don't change it.
  system.stateVersion = "25.05";

}
