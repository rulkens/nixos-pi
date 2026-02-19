{ ... }:
{
  imports = [
    ./headless-gl.nix
  ];

  # Load proprietary firmware for the Pi's VideoCore GPU. This is required
  # for the GPU to function at all — even on headless systems, the VideoCore
  # handles boot, power management, and hardware video decode.
  hardware.enableRedistributableFirmware = true;
}
