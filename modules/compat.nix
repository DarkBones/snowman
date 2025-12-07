{ lib, pkgs, config, inv, currentHost, ... }:
let
  hasHost = builtins.hasAttr currentHost inv.hosts;
  host = if hasHost then inv.hosts.${currentHost} else { };

  enableCompat = host.compatibility or false;
in {
  config = lib.mkIf (hasHost && enableCompat) {
    programs.nix-ld.enable = true;

    programs.nix-ld.libraries = with pkgs; [
      stdenv.cc.cc.lib # libstdc++
      zlib
      fuse3
      icu
      nss
      openssl
      curl
      expat
      glib
      util-linux
      libunwind
      libuuid
      xorg.libX11
      xorg.libXext
      xorg.libXi
      xorg.libXrender
      xorg.libXtst
      xorg.libxcb
      freetype
      fontconfig
    ];

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "run-unpatched" ''
        exec ${pkgs.nix-ld}/bin/nix-ld "$@"
      '')
    ];
  };
}
