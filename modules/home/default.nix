{
  config,
  pkgs,
  lib,
  ...
}:
let
  configPath = builtins.getEnv "NIXOS_PI_CONFIG";
  localCfg = builtins.fromJSON (builtins.readFile configPath);
  username = localCfg.username;
in
{
  options.rpi.home.enable = lib.mkEnableOption "home-manager user configuration";

  config = lib.mkIf config.rpi.home.enable {
    # zsh must be listed in /etc/shells for it to be a valid login shell.
    programs.zsh.enable = true;
    users.users.${username}.shell = pkgs.zsh;

    home-manager.users.${username} = {
      imports = [ ./zsh.nix ./fastfetch.nix ];

      rpi.home.fastfetch.enable = true;

      # Must match the NixOS stateVersion.
      home.stateVersion = "25.05";
    };
  };
}
