{ lib, inv, currentHost, ... }:
let
  hasHost = builtins.hasAttr currentHost inv.hosts;
  host = if hasHost then inv.hosts.${currentHost} else { };

  hasHw = hasHost && host ? hardware;
  hw = if hasHw then host.hardware else { };
  boot = hw.boot or { };

  # "bios" | "efi" | "none" | null
  fw = boot.firmware or null;

  dev = hw.bootDevice or null;
in {
  config = lib.mkIf (hasHost && hasHw && fw != null && fw != "none")
    (lib.mkMerge [
      # BIOS: use GRUB on the bootDevice (or /dev/vda as a sane VM default)
      (lib.mkIf (fw == "bios") {
        boot.loader.grub = {
          enable = true;
          devices = [ (if dev != null then dev else "/dev/vda") ];
          useOSProber = false;
        };
      })

      # EFI: use systemd-boot
      (lib.mkIf (fw == "efi") {
        boot.loader.systemd-boot.enable = true;
        boot.loader.efi = { canTouchEfiVariables = true; };
      })
    ]);
}
