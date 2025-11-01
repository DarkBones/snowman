{ config, home-manager, ... }: {
  imports = [
    ../../modules/base.nix
    ../../modules/hardware/qemu.nix
    ./hardware-configuration.nix
    home-manager.nixosModules.home-manager
  ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.bas = import ../../home/bas.nix;

  nix.settings = {
    substituters =
      [ "https://cache.nixos.org" "https://nix-community.cachix.org" ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
  networking.hostName = "vm-snowman";

  boot.loader.grub.enable = true;
  boot.loader.grub.devices = [ "/dev/vda" ];

  users.users.bas = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ # TODO: Make easy to configure
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMgJkfQdIJmmvaVQAJBvHiI5lMx/FdSVW3bJCXGQfAyL bas@dorkbones-2025-09-22"
    ];
  };

  security.sudo.wheelNeedsPassword = false;

  system.stateVersion = "25.05";
}
