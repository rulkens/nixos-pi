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
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # ------- Outputs -------
  outputs =
    {
      self,
      nixpkgs,
      home-manager,
    }:
    let
      # -------------------------------------------------------
      # Profiles
      # -------------------------------------------------------
      # Add a name here to expose a new nixosConfiguration and
      # package. Each name must have a matching profiles/<name>.nix.
      profiles = [
        "base"
        "home-automation"
      ];

      # Build a NixOS system for a given profile name.
      # Uses path concatenation (not string interpolation) because
      # Nix path literals cannot directly interpolate variables.
      makeConfig =
        name:
        nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            home-manager.nixosModules.home-manager
            "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
            (./profiles + "/${name}.nix")
            { sdImage.compressImage = false; }
          ];
        };

    in
    {
      # -------------------------------------------------------
      # NixOS Configurations
      # -------------------------------------------------------
      # One config per profile: nixosConfigurations.base,
      # nixosConfigurations.dev-box, etc.
      nixosConfigurations = builtins.listToAttrs (
        map (name: {
          inherit name;
          value = makeConfig name;
        }) profiles
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
          shell =
            system:
            let
              pkgs = import nixpkgs { inherit system; };
            in
            pkgs.mkShell {
              packages = with pkgs; [
                python3
                zstd
                git
              ];
              shellHook = ''
                h=$(printf '\033[38;5;183m')  # lavender   — section headers
                c=$(printf '\033[38;5;153m')  # sky blue   — commands
                a=$(printf '\033[38;5;120m')  # mint green — arguments / profiles
                d=$(printf '\033[38;5;250m')  # soft grey  — descriptions
                r=$(printf '\033[0m')          # reset

                printf "\n"
                printf "  ''${h}nixos-pi''${r}  —  NixOS Raspberry Pi image builder\n"
                printf "\n"
                printf "  ''${h}Build''${r}\n"
                printf "    ''${c}./build-image.sh''${r} ''${a}<profile>''${r}\n"
                printf "    ''${d}Build a bootable SD card image from a profile''${r}\n"
                printf "\n"
                printf "  ''${h}Deploy''${r}\n"
                printf "    ''${c}./deploy.sh''${r} ''${a}<profile>''${r}\n"
                printf "    ''${d}Switch a running Pi to the new config over SSH''${r}\n"
                printf "    ''${c}./deploy.sh --reconfigure''${r} ''${a}<profile>''${r}\n"
                printf "    ''${d}Regenerate config.json, then deploy''${r}\n"
                printf "\n"
                printf "  ''${h}Config''${r}\n"
                printf "    ''${c}./generate-config.py''${r}\n"
                printf "    ''${d}Generate or update config.json (WiFi, passwords, SSH key)''${r}\n"
                printf "\n"
                printf "  ''${h}Profiles''${r}\n"
                printf "    ''${a}base''${r}              ''${d}Minimal headless Pi — SSH, WiFi, mDNS''${r}\n"
                printf "    ''${a}home-automation''${r}   ''${d}Mosquitto, Zigbee2MQTT, Samba, headless GL, home-manager''${r}\n"
                printf "\n"

                unset h c a d r
              '';
            };
        in
        {
          aarch64-darwin.default = shell "aarch64-darwin";
          x86_64-darwin.default = shell "x86_64-darwin";
          aarch64-linux.default = shell "aarch64-linux";
        };
    };
}
