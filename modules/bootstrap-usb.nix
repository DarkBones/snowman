# modules/bootstrap-usb.nix

{ lib, inv, currentHost, sopsConfigPath, ... }:
let
  hasHost = builtins.hasAttr currentHost inv.hosts;
  host = if hasHost then inv.hosts.${currentHost} else { };

  # Read .sops.yaml purely as a string
  sopsContent = builtins.readFile sopsConfigPath;

  # Check if "&hostname" exists in the file.
  isRotated = !(builtins.match ".*&${currentHost} .*" sopsContent == null);

  # Logic: Enable USB ONLY if user wants it AND we haven't rotated yet.
  usbConfigured = host.bootstrap.usb.enable or false;
  usbEffective = usbConfigured && (!isRotated);

  profiles = host.profiles or [ ];
  isQemuGuest = lib.elem "qemu-guest" profiles;
in {
  # Expose this state so other modules (sops.nix) can see it
  options.snowman.isRotated = lib.mkOption {
    type = lib.types.bool;
    default = isRotated;
    internal = true;
    description = "True if the host key is present in .sops.yaml";
  };

  config = lib.mkIf (hasHost && usbEffective) {
    fileSystems."${host.bootstrap.usb.path}" = {
      device = "/dev/disk/by-label/${host.bootstrap.usb.label}";
      fsType = host.bootstrap.usb.fsType or "vfat";
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
