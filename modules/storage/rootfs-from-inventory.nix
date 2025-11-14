{ inv, currentHost, lib, ... }:
let
  hasHost = builtins.hasAttr currentHost inv.hosts;
  host = if hasHost then inv.hosts.${currentHost} else { };
  diskoOn = host.provision.disk.enable or false;
  hasHardware = host ? hardware;
  fs = if hasHardware then (host.hardware.fs or { }) else { };
  bootDevice = if hasHardware then host.hardware.bootDevice or null else null;

  mkPartitionDevice = device: part:
    let
      rawParts = lib.splitString "/" device;
      parts = lib.filter (p: p != "") rawParts;
      base = lib.last parts;
      needsSeparator = builtins.match ".*[0-9]$" base != null;
      sep = if needsSeparator then "p" else "";
    in "${device}${sep}${toString part}";

  partitionDevice =
    if bootDevice != null then
      if fs ? partition then mkPartitionDevice bootDevice fs.partition
      else if fs ? partitionNumber then mkPartitionDevice bootDevice fs.partitionNumber
      else null
    else null;

  explicitDevice = fs.device or null;
  labelDevice = if fs ? rootLabel then "/dev/disk/by-label/${fs.rootLabel}" else null;
  uuidDevice = if fs ? rootUuid then "/dev/disk/by-uuid/${fs.rootUuid}" else null;

  device = lib.findFirst (d: d != null) null
    [ explicitDevice partitionDevice labelDevice uuidDevice ];

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
