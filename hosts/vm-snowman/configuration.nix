{ config, home-manager, ... }: {
  imports = [
    ../../modules/hardware/qemu.nix
    ./hardware-configuration.nix
    ./users.nix
  ];

  networking.hostName = "vm-snowman";

  boot.loader.grub.enable = true;
  boot.loader.grub.devices = [ "/dev/vda" ];

  security.sudo.wheelNeedsPassword = true;
  system.stateVersion = "25.05";
}
