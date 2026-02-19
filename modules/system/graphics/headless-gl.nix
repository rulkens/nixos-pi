{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Headless OpenGL allows GL applications to render off-screen without a
  # physical display attached. This is useful for running graphical workloads
  # on the Pi — such as 3D rendering, simulation, or GUI automation — over
  # SSH or as background services.
  #
  # The approach uses Xvfb (X Virtual Framebuffer), a display server that
  # renders into memory rather than to real hardware. Applications see a
  # normal X11/GLX environment and never need to know there is no monitor.
  #
  # Typical usage:
  #   Xvfb :99 -screen 0 1920x1080x24 &
  #   DISPLAY=:99 <your-gl-application>
  options.rpi.system.headlessGL.enable = lib.mkEnableOption "headless GL support for Raspberry Pi";

  config = lib.mkIf config.rpi.system.headlessGL.enable {
    environment.systemPackages = with pkgs; [
      # Compiler toolchain needed to build native GL bindings and extensions.
      gcc
      gnumake
      pkg-config

      # X11 client libraries required by most GL/GLX applications.
      xorg.libX11   # Core X11 protocol
      xorg.libXi    # Input extension (mouse, keyboard events)
      xorg.libXext  # Miscellaneous X extensions (MIT-SHM, DPMS, …)

      # Xvfb — the virtual framebuffer X server. Provides a DISPLAY
      # that lives entirely in RAM with no GPU or monitor required.
      xorg.xorgserver

      # OpenGL utility libraries.
      libGLU  # GLU helper library (gluPerspective, gluLookAt, …)
      glew    # OpenGL Extension Wrangler — runtime GL function loading
    ];

    # Expose headers, libraries, and pkg-config files from the packages
    # above so that native compilation against them works out of the box.
    environment.pathsToLink = [
      "/include"
      "/lib"
      "/share"
    ];
  };
}
