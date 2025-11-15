# template/hosts/vm-snowman.nix
#
# Host-specific NixOS configuration for `vm-snowman`.
# This is where you:
#   - import the machine's hardware-configuration
#   - add host-specific modules/options if you want

{ ... }: {
  imports = [
    # Copy your /etc/nixos/hardware-configuration.nix into:
    #   ./hosts/vm-snowman-hardware-configuration.nix
    # and this import will pick it up.
    ./vm-snowman-hardware-configuration.nix
  ];

  # Example: host-local config could go here
  # networking.hostId = "deadbeef";
  # services.qemuGuest.enable = true;
}
