{
  # =========================================================
  # NixOS Raspberry Pi 4 — Flake Definition
  # =========================================================
  # This file is the entry point for the entire build.
  # It declares:
  #   1. Where to get our dependencies (inputs)
  #   2. What we produce (outputs):
  #      - A NixOS system config per profile
  #      - An SD card image per profile
  #      - A dev shell for building
  #
  # Profiles live in profiles/ and compose feature modules
  # from modules/. To add a new profile, create profiles/myname.nix
  # and add "myname" to the profiles list below.
  # =========================================================

  description = "NixOS Raspberry Pi 4 SD card image — multi-profile template";

  # ------- Inputs -------
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  # ------- Outputs -------
  outputs = { self, nixpkgs }:
    let
      # -------------------------------------------------------
      # Profiles
      # -------------------------------------------------------
      # Add a name here to expose a new nixosConfiguration and
      # package. Each name must have a matching profiles/<name>.nix.
      profiles = [ "base" "dev-box" ];

      # Build a NixOS system for a given profile name.
      # Uses path concatenation (not string interpolation) because
      # Nix path literals cannot directly interpolate variables.
      makeConfig = name: nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
          (./profiles + "/${name}.nix")
          ./local-config.nix
          { sdImage.compressImage = false; }
        ];
      };

    in {
      # -------------------------------------------------------
      # NixOS Configurations
      # -------------------------------------------------------
      # One config per profile: nixosConfigurations.base,
      # nixosConfigurations.dev-box, etc.
      nixosConfigurations = builtins.listToAttrs (
        map (name: { inherit name; value = makeConfig name; }) profiles
      );

      # -------------------------------------------------------
      # Packages
      # -------------------------------------------------------
      # SD card images: packages.aarch64-linux.base,
      #                 packages.aarch64-linux.dev-box, etc.
      #
      # Build with:
      #   nix build .#packages.aarch64-linux.base --impure
      packages.aarch64-linux = builtins.listToAttrs (
        map (name: {
          inherit name;
          value = self.nixosConfigurations.${name}.config.system.build.sdImage;
        }) profiles
      );

      # -------------------------------------------------------
      # Dev Shells
      # -------------------------------------------------------
      # Enter with: nix develop
      # Provides python3, zstd, git for running build.sh.
      devShells =
        let
          shell = system:
            let pkgs = import nixpkgs { inherit system; };
            in pkgs.mkShell {
              packages = with pkgs; [ python3 zstd git ];
              shellHook = ''echo "nixos-pi dev shell — run ./build.sh [profile]"'';
            };
        in {
          aarch64-darwin.default = shell "aarch64-darwin";
          x86_64-darwin.default  = shell "x86_64-darwin";
          aarch64-linux.default  = shell "aarch64-linux";
        };
    };
}
