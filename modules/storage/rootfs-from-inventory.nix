{ inv, currentHost, lib, ... }:
let
  hasHost = builtins.hasAttr currentHost inv.hosts;
  cfg = if !hasHost then
    { }
  else
    let
      host = inv.hosts.${currentHost};
      fs = host.hardware.fs;
      diskoOn = host.provision.disk.enable or false;
    in lib.mkIf (!diskoOn) {
      fileSystems."/" = {
        device = "/dev/disk/by-label/${fs.rootLabel}";
        fsType = fs.type;
      };
    };
in { } // cfg
