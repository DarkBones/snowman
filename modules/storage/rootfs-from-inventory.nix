# If host.provision.disk.enable = false and no hardware.fs is defined,
# Snowman delegates root mounting to the host's generated hardware-configuration.nix.
{ inv, currentHost, lib, ... }:
let hasHost = builtins.hasAttr currentHost inv.hosts;
in lib.mkIf hasHost (let
  host = inv.hosts.${currentHost};
  diskoOn = host.provision.disk.enable or false;
  hasHardware = host ? hardware;
  fs = if hasHardware then (host.hardware.fs or null) else null;
in lib.mkIf (hasHardware && !diskoOn && fs != null) {
  fileSystems."/" = {
    device = "/dev/disk/by-label/${fs.rootLabel or "nixos"}";
    fsType = fs.type or "ext4";
  };
})
