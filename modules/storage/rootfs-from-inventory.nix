{ inv, currentHost, lib, ... }:
let
  host = inv.hosts.${currentHost};
  fs = host.hardware.fs;
  diskoOn = host.provision.disk.enable or false;
in lib.mkIf (!diskoOn) {
  fileSystems."/" = {
    device = "/dev/disk/by-label/${fs.rootLabel}";
    fsType = fs.type;
  };

  boot.supportedFilesystems = lib.mkIf (fs.type == "btrfs") [ "btrfs" ];
}
