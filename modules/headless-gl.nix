{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.rpi.system.headlessGL;
in
{
  options.rpi.system.headlessGL = {
    enable = mkEnableOption "headless GL support for Raspberry Pi";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # Build essentials
      gcc
      gnumake
      pkg-config

      # X11 / GLX dependencies
      xorg.libX11
      xorg.libXi
      xorg.libXext
      xorg.xorgserver
      libGLU
      glew

      # Virtual framebuffer (Xvfb available via xorgserver)
      xorg.xorgserver
    ];

    environment.pathsToLink = [
      "/include"
      "/lib"
      "/share"
    ];
  };
}
