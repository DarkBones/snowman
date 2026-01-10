{ lib, inv, currentHost, ... }:
let
  hasHost = builtins.hasAttr currentHost inv.hosts;
  host = if hasHost then inv.hosts.${currentHost} else { };
  hasHw = hasHost && (host ? hardware);
  boot = if hasHw then host.hardware.boot else { };
  fw = boot.firmware or null;
in {
  config = lib.mkMerge [
    # Explicit opt-out
    (lib.mkIf (fw == "none") {
      boot.loader.grub.enable = lib.mkForce false;
      boot.loader.systemd-boot.enable = lib.mkForce false;
    })

    # Explicit BIOS
    (lib.mkIf (fw == "bios") {
      boot.loader.grub.enable = true;
      boot.loader.grub.devices = [ (host.hardware.bootDevice or "/dev/vda") ];
    })

    # Explicit EFI
    (lib.mkIf (fw == "efi") {
      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;
    })

    # Explicit Raspberry Pi
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
