{ pkgsUnstable, dotfilesSources, ... }: {
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
  ];
  home-manager.extraSpecialArgs = { inherit pkgsUnstable dotfilesSources; };
}
