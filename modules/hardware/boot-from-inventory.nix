{ lib, inv, currentHost, ... }:
let
  hasHost = builtins.hasAttr currentHost inv.hosts;
  host = if hasHost then inv.hosts.${currentHost} else { };
  hasHw = hasHost && (host ? hardware);
  boot = if hasHw then host.hardware.boot else { };
  fw = boot.firmware or null;
in {
  config = lib.mkMerge [
    # If the user provides *no* hardware block, disable ALL bootloaders.
    (lib.mkIf (!hasHw) {
      boot.loader.grub.enable = lib.mkForce false;
      boot.loader.systemd-boot.enable = lib.mkForce false;
    })

    # If firmware = "none", also disable bootloaders.
    (lib.mkIf (fw == "none") {
      boot.loader.grub.enable = lib.mkForce false;
      boot.loader.systemd-boot.enable = lib.mkForce false;
    })

    # Normal BIOS/EFI handling...
    (lib.mkIf (fw == "bios") {
      boot.loader.grub.enable = true;
      boot.loader.grub.devices = [ (host.hardware.bootDevice or "/dev/vda") ];
    })

    (lib.mkIf (fw == "efi") {
      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;
    })

    # Raspberry Pi specific hardening
    (lib.mkIf (fw == "raspberry-pi") {
      boot.loader.grub.enable = false;
      boot.loader.generic-extlinux-compatible.enable = true;

      # HARDENING: Trust the CPU's hardware RNG.
      # This ensures the kernel uses the Pi's built-in RNG to seed
      # the entropy pool immediately at boot.
      # services.rngd.enable = true;
    })
  ];
}
