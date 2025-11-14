{ lib, inv, currentHost, ... }:
let
  hasHost = builtins.hasAttr currentHost inv.hosts;
  host = if hasHost then inv.hosts.${currentHost} else { };
  diskoOn = (host.provision.disk.enable or false);
in lib.mkIf (hasHost && !diskoOn) {
  boot.loader.grub.enable = true;
  boot.loader.grub.devices = [ "/dev/vda" ];
}
