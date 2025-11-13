{ lib, pkgsUnstable, dotfilesSources, ... }: {
  imports = [
    ./hardware/from-inventory.nix
    ./home/from-inventory.nix
    ./storage/rootfs-from-inventory.nix
    ./users/from-inventory.nix
    ./bootstrap-usb.nix
    ./host-secrets-from-inventory.nix
    ./nix.nix
    ./security.nix
    ./sops.nix
    ./ssh.nix
  ] ++ lib.optional (builtins.pathExists /etc/nixos/hardware-configuration.nix)
    /etc/nixos/hardware-configuration.nix
    ++ lib.optional (!builtins.pathExists /etc/nixos/hardware-configuration.nix)
    ({ ... }: {
      fileSystems."/" = {
        device = "/dev/disk/by-label/nixos";
        fsType = "ext4";
      };
      boot.loader.grub.devices = [ "/dev/vda" ];
    });

  home-manager.extraSpecialArgs = { inherit pkgsUnstable dotfilesSources; };
}
