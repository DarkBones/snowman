{ inv, lib, currentHost, ... }:

let
  hasHost = builtins.hasAttr currentHost inv.hosts;
  host = if hasHost then inv.hosts.${currentHost} else { };

  diskoOn = hasHost && (host.provision.disk.enable or false);

  baseCfg = lib.mkIf hasHost {
    # Safety: inventory must contain this host
    assertions = [{
      assertion = hasHost;
      message = "Inventory: host ${currentHost} not found in inv.hosts";
    }];

    networking.hostName = host.hostname or currentHost;
    networking.useDHCP = host.useDHCP or true;

    # Tie system.stateVersion to your inventory release
    system.stateVersion = inv.release;

    # Simple BIOS GRUB on a single disk (your VM)
    boot.loader.grub = {
      enable = true;
      devices = lib.mkForce [ host.hardware.disk.device ];
    };

    # Explicitly keep systemd-boot off for now
    boot.loader.systemd-boot.enable = false;
  };

  diskoCfg = lib.mkIf diskoOn {
    disko.devices.disk.main = {
      type = "disk";
      device = host.hardware.disk.device;
      content = {
        type = "gpt";
        partitions = {
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

in { config = lib.mkMerge [ baseCfg diskoCfg ]; }
