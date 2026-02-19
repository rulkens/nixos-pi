{
  config,
  pkgs,
  lib,
  ...
}:
{
  options.rpi.services.tailscale.enable = lib.mkEnableOption "Tailscale VPN";

  config = lib.mkIf config.rpi.services.tailscale.enable {
    services.tailscale.enable = true;
    networking.firewall.allowedUDPPorts = [ 41641 ];
    networking.firewall.trustedInterfaces = [ "tailscale0" ];
    networking.firewall.checkReversePath = "loose";
  };
}
