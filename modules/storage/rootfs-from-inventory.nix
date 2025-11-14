{ inv, currentHost, lib, ... }:
let
  hasHost = builtins.hasAttr currentHost inv.hosts;
  host = if hasHost then inv.hosts.${currentHost} else { };
  diskoOn = host.provision.disk.enable or false;
  hasHardware = host ? hardware;
  fs = if hasHardware then (host.hardware.fs or null) else null;

  device = if fs ? rootUuid then
    "/dev/disk/by-uuid/${fs.rootUuid}"
  else if fs ? rootLabel then
    "/dev/disk/by-label/${fs.rootLabel}"
  else
    null;

in {
  config = lib.mkIf
    (hasHardware && !diskoOn && device != null && host.hardware ? bootDevice) {

      fileSystems."/" = {
        inherit device;
        fsType = fs.type or "ext4";
      };

      boot.loader.grub = {
        enable = true;
        devices = [ host.hardware.bootDevice ];
      };
    };
}
