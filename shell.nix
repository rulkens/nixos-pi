{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  packages = with pkgs; [ python3 zstd git ];
  shellHook = ''echo "nixos-pi dev shell — run ./build.sh [profile]"'';
}
