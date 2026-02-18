{ config, pkgs, lib, ... }:
{
  options.rpi.avahi.enable = lib.mkEnableOption "Avahi mDNS daemon";

  config = lib.mkIf config.rpi.avahi.enable {
    # Enable mDNS/DNS-SD via Avahi. This lets you find your
    # Pi on the local network as "<hostname>.local" instead
    # of having to look up its IP address. So if your hostname
    # is "rpi", you can do: ssh user@rpi.local
    services.avahi = {
      enable = true;
      nssmdns4 = true; # Enable mDNS resolution for IPv4
      publish = {
        enable = true;
        addresses = true; # Publish our IP address
      };
    };
  };
}
