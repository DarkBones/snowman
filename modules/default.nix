{ ... }: {
  imports =
    [ ./ssh.nix ./hardware/from-inventory.nix ./users/from-inventory.nix ];
}
