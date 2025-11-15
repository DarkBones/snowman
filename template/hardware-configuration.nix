# template/hardware-configuration.nix
#
# Snowman template placeholder.
#
# On a real system, AFTER installing NixOS normally, copy your real
# hardware config from /etc/nixos into this repo:
#
#   sudo cp /etc/nixos/hardware-configuration.nix ./hardware-configuration.nix
#
# Then edit inventory.nix as needed and use:
#
#   sudo nixos-rebuild switch --flake .#<your-host>
#
{ lib, ... }: {
  # Fail loudly if you forgot to replace this file.
  assertions = [{
    assertion = false;
    message = ''
      Snowman template: please replace template/hardware-configuration.nix
      with your real /etc/nixos/hardware-configuration.nix before using
      this flake on a real machine.
    '';
  }];
}
