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

  networking.hostName = "vm-snowman";

  boot.loader.grub.enable = true;
  boot.loader.grub.devices = [ "/dev/vda" ];

  # TODO: Have users be file-based. I.e. each user has a file in some subdirectory
  users.users.bas = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ (builtins.readFile ../../keys/bas.pub) ];
  };

  security.sudo.wheelNeedsPassword = false;
  system.stateVersion = "25.05";
}
