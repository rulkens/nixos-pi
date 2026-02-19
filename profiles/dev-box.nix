{ ... }:
{
  imports = [ ../modules ];

  rpi.services.samba.enable = true;
  rpi.services.mosquitto.enable = true;
  rpi.services.zigbee2mqtt.enable = true;
  rpi.system.headlessGL.enable = true;
  rpi.home.enable = true;
}
