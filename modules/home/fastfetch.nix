{ config, lib, ... }:
{
  options.rpi.home.fastfetch.enable = lib.mkEnableOption "fastfetch system info on login";

  config = lib.mkIf config.rpi.home.fastfetch.enable {
    programs.fastfetch = {
      enable = true;
      settings = {
        logo = {
          source = "nixos";
          type = "builtin";
          padding = {
            right = 1;
          };
        };
      };
    };
  };
}
