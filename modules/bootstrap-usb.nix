{ lib, inv, currentHost, sopsConfigPath, ... }:
let
  hasHost = builtins.hasAttr currentHost inv.hosts;
  host = if hasHost then inv.hosts.${currentHost} else { };

  sopsContent = builtins.readFile sopsConfigPath;

  # Detect '&<host>' followed by whitespace or EOL.
  builtins.match ".*&${currentHost}([^A-Za-z0-9_-]|$).*" sopsContent != null;

  usbConfigured = host.bootstrap.usb.enable or false;
  usbEffective = usbConfigured && (!isRotated);

  profiles = host.profiles or [ ];
  isQemuGuest = lib.elem "qemu-guest" profiles;
in {
  config = lib.mkMerge [
    { snowman.isRotated = isRotated; }

    (lib.mkIf (hasHost && usbEffective) {
      fileSystems."${host.bootstrap.usb.path}" = {
        device = "/dev/disk/by-label/${host.bootstrap.usb.label}";
        fsType = host.bootstrap.usb.fsType or "vfat";
        options = [ "nofail" ];
      };
    })

    {
      assertions = [{
        assertion = !(hasHost && usbEffective && isQemuGuest);
        message = ''
          ❌ Snowman: 'bootstrap.usb.enable = true' is set on host "${currentHost}",
              which also uses the 'qemu-guest' profile.
          ...
        '';
      }];
    }
  ];
}
