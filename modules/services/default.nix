# =========================================================
# Services — opt-in feature modules
# =========================================================
# Each file in this directory defines one self-contained
# service. All modules are always imported, but nothing is
# enabled unless a profile explicitly sets the option to true.
#
# How to add a new service module
# ---------------------------------
# 1. Create modules/services/myservice.nix with this shape:
#
#      { config, pkgs, lib, ... }:
#      {
#        options.rpi.services.myservice.enable =
#          lib.mkEnableOption "short description";
#
#        config = lib.mkIf config.rpi.services.myservice.enable {
#          services.myservice.enable = true;
#          networking.firewall.allowedTCPPorts = [ 1234 ];
#          # ... any other NixOS options
#        };
#      }
#
# 2. Add ./myservice.nix to the imports list below.
#
# 3. Enable it in a profile:
#
#      rpi.services.myservice.enable = true;
#
# If the service needs credentials from config.json, read
# them at the top of the module file:
#
#   let
#     configPath = builtins.getEnv "NIXOS_PI_CONFIG";
#     localCfg   = builtins.fromJSON (builtins.readFile configPath);
#   in
# =========================================================

{ ... }:
{
  imports = [
    ./avahi.nix
    ./docker.nix
    ./mosquitto.nix
    ./samba.nix
    ./tailscale.nix
    ./zigbee2mqtt.nix
  ];
}
