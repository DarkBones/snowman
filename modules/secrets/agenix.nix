{ lib, inv, currentHost, ... }:
let
  hasHost = builtins.hasAttr currentHost inv.hosts;
  host = if hasHost then inv.hosts.${currentHost} else { };
  usbCfg = host.bootstrap.usb or { enable = false; };
in {

  config = {
    age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ]
      ++ lib.optionals usbCfg.enable [ "${usbCfg.path}/${usbCfg.keyFile}" ];

    fileSystems = lib.optionalAttrs usbCfg.enable {
      "${usbCfg.path}" = {
        device = "/dev/disk/by-label/${usbCfg.label}";
        fsType = usbCfg.fsType or "vfat";
        # options = [ "nofail" "x-systemd.automount" ];
        options = [ "nofail" ];
      };
    };
  };
}
