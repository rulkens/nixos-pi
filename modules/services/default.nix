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
