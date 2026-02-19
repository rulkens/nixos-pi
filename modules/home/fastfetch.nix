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
          padding.right = 1;
        };
        modules = [
          "title"
          "separator"

          # System
          "os"
          "host"
          "kernel"
          "uptime"
          "packages"
          "shell"

          "separator"

          # Hardware
          "cpu"
          "memory"
          { type = "disk"; folders = "/"; }

          "separator"

          # Network
          { type = "localip"; format = "{ipv4} ({ifname})"; showIpV6 = false; }

          # NixOS
          {
            type = "command";
            key = "NixOS Gen";
            shell = "sh";
            text = "readlink /nix/var/nix/profiles/system 2>/dev/null | tr -cd '0-9' || echo 'N/A'";
          }

          "break"
          "colors"
        ];
      };
    };
  };
}
