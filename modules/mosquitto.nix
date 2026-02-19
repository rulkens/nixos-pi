{
  config,
  lib,
  ...
}:
let
  configPath = builtins.getEnv "NIXOS_PI_CONFIG";
  localCfg = builtins.fromJSON (builtins.readFile configPath);
  mqttUser = localCfg.username;
  mqttPassword = localCfg.mqtt.password;
  mqttClientPassword = localCfg.mqtt.clientPassword;

in
{
  options.rpi.mosquitto.enable = lib.mkEnableOption "Mosquitto MQTT broker";

  config = lib.mkIf config.rpi.mosquitto.enable {
    services.mosquitto = {
      enable = true;
      listeners = [
        {
          # Plain MQTT
          port = 1883;
          omitPasswordAuth = false;
          users.${mqttUser}.password = mqttPassword;
          users.client.password = mqttClientPassword;
        }
        {
          # MQTT over WebSockets
          port = 9001;
          omitPasswordAuth = false;
          users.${mqttUser}.password = mqttPassword;
          users.client.password = mqttClientPassword;
          settings.protocol = "websockets";
        }
      ];
    };

    networking.firewall.allowedTCPPorts = [
      1883
      9001
    ];
  };
}
