{ config, pkgs, lib, ... }:
let
  configPath = builtins.getEnv "NIXOS_PI_CONFIG";
  localCfg = builtins.fromJSON (builtins.readFile configPath);
  mqttUser = localCfg.username;
  mqttPassword = localCfg.mqttPassword;
  mqttClientPassword = localCfg.mqttClientPassword;
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
          omitPasswordAuth = true; # password file managed by activation script
          settings = {
            allow_anonymous = false;
            password_file = "/var/lib/mosquitto/passwd";
          };
        }
        {
          # MQTT over WebSockets
          port = 9001;
          omitPasswordAuth = true;
          settings = {
            allow_anonymous = false;
            password_file = "/var/lib/mosquitto/passwd";
            protocol = "websockets";
          };
        }
      ];
    };

    networking.firewall.allowedTCPPorts = [ 1883 9001 ];

    # Create the Mosquitto password file at activation time.
    # mosquitto_passwd -b writes a hashed entry; -c creates/truncates the file.
    # The second call adds the client user without -c so the first entry is kept.
    system.activationScripts.mosquitto-passwd = {
      deps = [ "users" ];
      text = ''
        install -d -m 750 -o mosquitto -g mosquitto /var/lib/mosquitto
        ${pkgs.mosquitto}/bin/mosquitto_passwd -b -c /var/lib/mosquitto/passwd \
          ${mqttUser} '${mqttPassword}'
        ${pkgs.mosquitto}/bin/mosquitto_passwd -b /var/lib/mosquitto/passwd \
          client '${mqttClientPassword}'
        chown mosquitto:mosquitto /var/lib/mosquitto/passwd
        chmod 640 /var/lib/mosquitto/passwd
      '';
    };
  };
}
