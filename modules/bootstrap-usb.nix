{ lib, inv, currentHost, ... }:
let
  hasHost = builtins.hasAttr currentHost inv.hosts;
  host = if hasHost then inv.hosts.${currentHost} else { };
  usbCfg = host.bootstrap.usb or { enable = false; };
in {
  config = lib.mkIf (hasHost && usbCfg.enable) {
    fileSystems.${usbCfg.path} = {
      device = "/dev/disk/by-label/${usbCfg.label}";
      fsType = usbCfg.fsType or "vfat";
      options = [ "nofail" ];
    };
  };
}
