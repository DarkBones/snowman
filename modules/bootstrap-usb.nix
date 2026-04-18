{
  lib,
  inv,
  currentHost,
  sopsConfigPath,
  ...
}:
let
  hasHost = builtins.hasAttr currentHost inv.hosts;
  host = if hasHost then inv.hosts.${currentHost} else { };

  usbCfg = ((host.bootstrap or { }).usb or { });
  usbConfigured = usbCfg.enable or false;

  sopsContent = builtins.readFile sopsConfigPath;

  hostRe = lib.escapeRegex currentHost;

  isRotated = builtins.match ".*&${hostRe}([^A-Za-z0-9_-]|$).*" sopsContent != null;

  usbEffective = usbConfigured && (!isRotated);

  profiles = host.profiles or [ ];
  isQemuGuest = lib.elem "qemu-guest" profiles;
in
{
  config = lib.mkMerge [
    { snowman.isRotated = isRotated; }

    (lib.mkIf (hasHost && usbEffective) {
      fileSystems."${usbCfg.path}" = {
        device = "/dev/disk/by-label/${usbCfg.label}";
        fsType = usbCfg.fsType or "vfat";
        options = [ "nofail" ];
      };
    })

    {
      assertions = [
        {
          assertion = !(hasHost && usbEffective && isQemuGuest);
          message = ''
            ❌ Snowman: 'bootstrap.usb.enable = true' is set on host "${currentHost}",
                which also uses the 'qemu-guest' profile.

                This will fail the boot, as the USB key script cannot run in a VM.

                Fix: Set 'bootstrap.usb.enable = false;' in your inventory.nix for this host.
          '';
        }

        {
          assertion = !(hasHost && usbConfigured) || (usbCfg ? path && usbCfg ? label && usbCfg ? keyFile);
          message = ''
            ❌ Snowman: bootstrap.usb.enable = true on "${currentHost}" but bootstrap.usb.{path,label,keyFile} is incomplete.
          '';
        }
      ];
    }
  ];
}
