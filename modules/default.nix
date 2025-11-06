{ ... }: {
  imports = [
    ./ssh.nix
    ./hardware/from-inventory.nix
    ./users/from-inventory.nix
    ./secrets/agenix.nix
  ];
}
