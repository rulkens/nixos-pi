{ ... }:
{
  imports = [
    ../modules/base.nix
    ../modules/services/docker.nix
    ../modules/services/tailscale.nix
    ../modules/services/samba.nix
    ../modules/services/mosquitto.nix
    ../modules/services/zigbee2mqtt.nix
    ../modules/headless-gl.nix
    ../modules/home.nix
  ];

  rpi.docker.enable = false;
  rpi.tailscale.enable = false;
  rpi.samba.enable = true;
  rpi.mosquitto.enable = true;
  rpi.zigbee2mqtt.enable = true;
  rpi.headlessGL.enable = true;
  rpi.home.enable = true;
}
