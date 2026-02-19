{ ... }:
{
  imports = [ ../modules ];

  # mDNS — lets you reach the Pi as <hostname>.local on the local network.
  rpi.services.avahi.enable = true;
}
