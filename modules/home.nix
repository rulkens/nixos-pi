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
      programs.zsh = {
        enable = true;
        oh-my-zsh = {
          enable = true;
          theme = "robbyrussell";
          plugins = [
            "git"    # git aliases and branch in prompt
            "sudo"   # press ESC twice to prepend sudo
            "z"      # frecency-based cd
          ];
        };
      };

      # Must match the NixOS stateVersion.
      home.stateVersion = "25.05";
    };
  };
}
