{ inv, lib, ... }:
let
  hosts = inv.hosts;
  mk = name: attrs:
    { ... }:
    let
      fw = attrs.hardware.boot.firmware or "bios";
      loader = if fw == "efi" then "systemd-boot" else "grub";
      espSz = attrs.hardware.boot.espSize or "512MiB";
    in {
      networking.hostName = attrs.hostname or name;
      networking.useDHCP = attrs.useDHCP or true;
      system.stateVersion = inv.release;

      # Bootloader
      boot.loader.grub = lib.mkMerge [
        (lib.mkIf (fw == "bios") {
          enable = true;
          mirroredBoots = [{
            devices = [ attrs.hardware.disk.device ];
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
        lib.mkIf (fw == "efi" && loader == "systemd-boot") true;
      boot.loader.efi = lib.mkIf (fw == "efi") {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };

      ## Disk layout (disko)
      disko.devices.disk.main = {
        type = "disk";
        device = attrs.hardware.disk.device;
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
                format = attrs.hardware.fs.type; # "btrfs" | "ext4" | …
                extraArgs = [ "-L" attrs.hardware.fs.rootLabel ];
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
in { imports = lib.attrValues (lib.mapAttrs mk hosts); }
