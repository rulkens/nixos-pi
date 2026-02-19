{
  config,
  lib,
  ...
}:
let
  configPath = builtins.getEnv "NIXOS_PI_CONFIG";
  localCfg = builtins.fromJSON (builtins.readFile configPath);
  z2mCfg = localCfg.zigbee2mqtt;
in
{
  options.rpi.services.zigbee2mqtt.enable = lib.mkEnableOption "Zigbee2MQTT bridge";

  config = lib.mkIf config.rpi.services.zigbee2mqtt.enable {
    # Register the zigbee2mqtt MQTT user with the broker.
    # Requires modules/mosquitto.nix to be imported in the same profile.
    rpi.services.mosquitto.extraUsers.zigbee2mqtt = z2mCfg.mqttPassword;

    services.zigbee2mqtt = {
      enable = true;
      settings = {
        permit_join = false;
        mqtt = {
          server = "mqtt://localhost:${toString config.rpi.services.mosquitto.port}";
          user = "zigbee2mqtt";
          password = z2mCfg.mqttPassword;
        };
        serial.port = z2mCfg.serialPort;
        frontend = {
          enabled = true;
          port = 8080;
        };
      };
    };

    # The Zigbee USB adapter is owned by the dialout group.
    users.users.zigbee2mqtt.extraGroups = [ "dialout" ];

    # Zigbee2MQTT web frontend
    networking.firewall.allowedTCPPorts = [ 8080 ];
  };
}
