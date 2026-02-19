# =========================================================
# Example: Node.js application from a Git repository
# =========================================================
# This module clones a Git repo, runs `npm install`, executes
# an optional post-install script, and then starts the app as
# a managed systemd service.
#
# Enable in a profile:
#
#   rpi.services.nodejsApp = {
#     enable   = true;
#     repoUrl  = "https://github.com/yourorg/your-app.git";
#     branch   = "main";
#     appDir   = "/opt/my-app";
#     start    = "node index.js";
#     port     = 3000;
#   };
#
# The setup service runs on every boot and pulls the latest
# commits before (re)starting the app. To update the app,
# simply reboot or restart the setup service:
#
#   sudo systemctl restart nodejs-app-setup
# =========================================================

{
  config,
  pkgs,
  lib,
  ...
}:
let
  configPath = builtins.getEnv "NIXOS_PI_CONFIG";
  localCfg = builtins.fromJSON (builtins.readFile configPath);
  cfg = config.rpi.services.nodejsApp;

  node = pkgs.nodejs_24;
in
{
  options.rpi.services.nodejsApp = {
    enable = lib.mkEnableOption "Node.js application from a Git repository";

    repoUrl = lib.mkOption {
      type = lib.types.str;
      description = "Git repository URL to clone.";
      example = "https://github.com/yourorg/your-app.git";
    };

    branch = lib.mkOption {
      type = lib.types.str;
      default = "main";
      description = "Git branch to track.";
    };

    appDir = lib.mkOption {
      type = lib.types.str;
      default = "/opt/nodejs-app";
      description = "Directory to clone the repository into.";
    };

    start = lib.mkOption {
      type = lib.types.str;
      default = "node index.js";
      description = "Command used to start the application (relative to appDir).";
      example = "npm start";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "TCP port the application listens on. Opened in the firewall.";
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Extra environment variables passed to the running application.";
      example = { LOG_LEVEL = "info"; };
    };
  };

  config = lib.mkIf cfg.enable {

    # -------------------------------------------------------
    # Setup service — runs once on boot before the app starts
    # -------------------------------------------------------
    # Clones the repo on first run, pulls on subsequent boots,
    # installs npm dependencies, and runs the post-install
    # script if one is present in the repository.
    systemd.services.nodejs-app-setup = {
      description = "Set up Node.js application (clone / pull / npm install)";

      # Run before the app service, after the network is up.
      wantedBy = [ "multi-user.target" ];
      before   = [ "nodejs-app.service" ];
      after    = [ "network-online.target" ];
      wants    = [ "network-online.target" ];

      serviceConfig = {
        Type            = "oneshot";
        RemainAfterExit = true;
        User            = localCfg.username;
      };

      path = [ node pkgs.git pkgs.bash ];

      script = ''
        set -euo pipefail

        # --- Clone or update the repository ---
        if [ ! -d "${cfg.appDir}/.git" ]; then
          echo "Cloning ${cfg.repoUrl} into ${cfg.appDir}..."
          git clone --branch ${cfg.branch} ${cfg.repoUrl} ${cfg.appDir}
        else
          echo "Pulling latest changes on branch ${cfg.branch}..."
          git -C ${cfg.appDir} fetch origin
          git -C ${cfg.appDir} checkout ${cfg.branch}
          git -C ${cfg.appDir} reset --hard origin/${cfg.branch}
        fi

        # --- Install npm dependencies ---
        echo "Running npm install..."
        cd ${cfg.appDir}
        npm install --omit=dev

        # --- Post-install script (optional) ---
        # Place a script at scripts/post-install.sh in your repo to run
        # any setup steps — database migrations, config generation, etc.
        if [ -f "${cfg.appDir}/scripts/post-install.sh" ]; then
          echo "Running post-install script..."
          bash ${cfg.appDir}/scripts/post-install.sh
        fi

        echo "Setup complete."
      '';
    };

    # -------------------------------------------------------
    # Application service — runs the app continuously
    # -------------------------------------------------------
    systemd.services.nodejs-app = {
      description = "Node.js application";

      wantedBy = [ "multi-user.target" ];
      after    = [ "nodejs-app-setup.service" ];
      requires = [ "nodejs-app-setup.service" ];

      environment = {
        NODE_ENV = "production";
        PORT     = toString cfg.port;
      } // cfg.environment;

      serviceConfig = {
        Type             = "simple";
        User             = localCfg.username;
        WorkingDirectory = cfg.appDir;
        ExecStart        = "${node}/bin/${cfg.start}";

        # Restart automatically on crash, with a short back-off.
        Restart    = "on-failure";
        RestartSec = "5s";

        # Basic hardening — limits what the service can access.
        ProtectSystem       = "strict";
        ProtectHome         = "read-only";
        ReadWritePaths      = [ cfg.appDir ];
        NoNewPrivileges     = true;
        PrivateTmp          = true;
      };
    };

    # Open the app's port in the firewall.
    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
