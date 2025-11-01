{ config, home-manager, ... }: {
  imports = [
    ../../modules/base.nix
    ../../modules/hardware/qemu.nix
    ./hardware-configuration.nix
    ./users.nix
    home-manager.nixosModules.home-manager
  ];

  networking.hostName = "vm-snowman";

  boot.loader.grub.enable = true;
  boot.loader.grub.devices = [ "/dev/vda" ];

  security.sudo.wheelNeedsPassword = false;
  system.stateVersion = "25.05";
}
