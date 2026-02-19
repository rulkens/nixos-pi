{
  config,
  pkgs,
  lib,
  ...
}:
let
  configPath = builtins.getEnv "NIXOS_PI_CONFIG";
  localCfg = builtins.fromJSON (builtins.readFile configPath);
in
{
  options.rpi.services.docker.enable = lib.mkEnableOption "Docker container runtime";

  config = lib.mkIf config.rpi.services.docker.enable {
    virtualisation.docker.enable = true;
    virtualisation.docker.autoPrune = {
      enable = true;
      dates = "weekly";
    };
    environment.systemPackages = [ pkgs.docker-compose ];

    # Add the user to the docker group so they can run containers
    # without sudo. Kept here rather than in user.nix so that the
    # docker group is only present when Docker is actually enabled.
    users.groups.docker.members = [ localCfg.username ];
  };
}
