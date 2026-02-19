{
  config,
  pkgs,
  lib,
  ...
}:
let
  configPath = builtins.getEnv "NIXOS_PI_CONFIG";
  localCfg = builtins.fromJSON (builtins.readFile configPath);
  sambaUser = localCfg.username;
  sambaPass = localCfg.sambaPassword;
  sambaHost = localCfg.hostname;
in
{
  options.rpi.services.samba.enable = lib.mkEnableOption "Samba home directory share";

  config = lib.mkIf config.rpi.services.samba.enable {
    # WS-Discovery: makes the Pi appear in Windows Explorer / macOS Finder sidebar
    services.samba-wsdd.enable = true;

    services.samba = {
      enable = true;
      openFirewall = true;
      settings = {
        global = {
          workgroup = "WORKGROUP";
          "server string" = sambaHost;
          "server role" = "standalone server";
          "map to guest" = "never";
          security = "user";
        };
        # Share named after the username → \\<hostname>\<username>
        "${sambaUser}" = {
          path = "/home/${sambaUser}";
          "valid users" = sambaUser;
          "read only" = "no";
          browseable = "yes";
          "create mask" = "0644";
          "directory mask" = "0755";
        };
      };
    };

    # Create/update the Samba user account and set its password at activation time.
    # deps = ["users"] ensures the Linux user exists before smbpasswd runs.
    # Running on every activation is idempotent — smbpasswd -a updates if the user exists.
    system.activationScripts.samba-user-password = {
      deps = [ "users" ];
      text = ''
        ${pkgs.samba}/bin/smbpasswd -L -a -s ${sambaUser} <<EOF
        ${sambaPass}
        ${sambaPass}
        EOF
        ${pkgs.samba}/bin/smbpasswd -L -e ${sambaUser}
      '';
    };
  };
}
