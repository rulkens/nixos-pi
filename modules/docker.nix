{ config, pkgs, lib, ... }:
{
  options.rpi.docker.enable = lib.mkEnableOption "Docker container runtime";

  config = lib.mkIf config.rpi.docker.enable {
    virtualisation.docker.enable = true;
    virtualisation.docker.autoPrune = {
      enable = true;
      dates = "weekly";
    };
    environment.systemPackages = [ pkgs.docker-compose ];
  };
}
