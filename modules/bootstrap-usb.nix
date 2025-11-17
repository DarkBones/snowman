{ lib, inv, currentHost, ... }:
let
  hasHost = builtins.hasAttr currentHost inv.hosts;
  host = if hasHost then inv.hosts.${currentHost} else { };
  usbCfg = host.bootstrap.usb or { enable = false; };
  profiles = host.profiles or [ ];
  isQemuGuest = lib.elem "qemu-guest" profiles;
in {
  config = lib.mkIf (hasHost && usbCfg.enable) {
    fileSystems.${usbCfg.path} = {
      device = "/dev/disk/by-label/${usbCfg.label}";
      fsType = usbCfg.fsType or "vfat";
      options = [ "nofail" ];
    };

    assertions = [{
      assertion = !isQemuGuest;
      message = ''
        ❌ Snowman: 'bootstrap.usb.enable = true' is set on host "${currentHost}",
           which also uses the 'qemu-guest' profile.

           This will fail the boot, as the USB key script cannot run in a VM.

           Fix: Set 'bootstrap.usb.enable = false;' in your inventory.nix for this host.
      '';
    }];
  };
}
