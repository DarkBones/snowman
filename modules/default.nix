{ pkgsUnstable, ... }: {
  imports = [
    ./ssh.nix
    ./hardware/from-inventory.nix
    ./storage/rootfs-from-inventory.nix
    ./users/from-inventory.nix
    ./secrets/agenix.nix
    ./secrets/env.nix
    ./security.nix
    ./nix.nix
    ./home/from-inventory.nix
  ];
  home-manager.extraSpecialArgs = { inherit pkgsUnstable; };
}
