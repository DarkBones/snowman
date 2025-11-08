{ inv, lib, currentHost, ... }:
let
  hasHost = builtins.hasAttr currentHost inv.hosts;
  cfg = if !hasHost then
    { }
  else
    let
      host = inv.hosts.${currentHost};
      fw = host.hardware.boot.firmware or "bios";
      loader = if fw == "efi" then "systemd-boot" else "grub";
      espSz = host.hardware.boot.espSize or "512MiB";
    in {
      networking.hostName = host.hostname or currentHost;
      networking.useDHCP = host.useDHCP or true;
      system.stateVersion = inv.release;

      # Bootloader
      boot.loader.grub = lib.mkMerge [
        (lib.mkIf (fw == "bios") {
          enable = true;
          mirroredBoots = [{
            devices = [ host.hardware.disk.device ];
            path = "/";
          }];
          devices = lib.mkForce [ ];
        })
        (lib.mkIf (fw == "efi" && loader == "grub") {
          enable = true;
          efiSupport = true;
          efiInstallAsRemovable = true;
          devices = lib.mkForce [ ];
        })
      ];

      # EFI -> pick loader
      boot.loader.systemd-boot.enable =
        (fw == "efi" && loader == "systemd-boot");

      boot.loader.efi = lib.mkIf (fw == "efi") {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };

      disko.devices.disk.main = lib.mkIf host.provision.disk.enable {
        type = "disk";
        device = host.hardware.disk.device;
        content = {
          type = "gpt";
          partitions = (lib.optionalAttrs (fw == "bios") {
            bios = {
              size = "1M";
              type = "EF02";
            };
          }) // (lib.optionalAttrs (fw == "efi") {
            esp = {
              size = espSz;
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
          }) // {
            root = {
              size = "100%";
              type = "8300";
              content = {
                type = "filesystem";
                format = host.hardware.fs.type; # "btrfs" | "ext4" | …
                extraArgs = [ "-L" host.hardware.fs.rootLabel ];
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
in {
  assertions = [{
    assertion = hasHost;
    message = "Inventory: host ${currentHost} not found in inv.hosts";
  }];
} // cfg
