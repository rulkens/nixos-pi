{ ... }:
{
  nix.settings = {
    # Enable flakes and the new nix command on the Pi itself,
    # so you can use `nix build`, `nix shell`, etc. when logged in.
    experimental-features = [
      "nix-command"
      "flakes"
    ];

    # Allow wheel users to push unsigned store paths, which is required
    # for nixos-rebuild switch deployments from a remote build host.
    trusted-users = [
      "root"
      "@wheel"
    ];
  };

  # Automatic garbage collection to prevent the SD card from filling up
  # with old package versions and superseded system generations.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
}
