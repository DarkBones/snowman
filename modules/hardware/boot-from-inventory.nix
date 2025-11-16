{ lib, inv, currentHost, ... }:
let
  hasHost = builtins.hasAttr currentHost inv.hosts;
  host = if hasHost then inv.hosts.${currentHost} else { };
  hw = host.hardware or { };
  boot = hw.boot or { };
  fw = boot.firmware or "bios"; # "bios" | "efi"
  dev = hw.bootDevice or null;
in {
  config = lib.mkIf hasHost (lib.mkMerge [
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
