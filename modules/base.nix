{ lib, ... }: {
  snowman.base.present = true;
  imports = [
    ./security/ssh.nix
    ./security/ssh-crypto.nix
    ./security/hardening-min.nix
    ./security/hardening-kernel.nix
    ./security/lsm.nix
    ./secrets/dotfiles-key.nix
    ../modules/bootstrap.nix
  ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  time.timeZone = "Europe/Berlin";
  nixpkgs.config.allowUnfree = true;
  users.mutableUsers = lib.mkDefault false;

  security.sudo.extraConfig = ''
    Defaults !tty_tickets
  '';

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    substituters =
      [ "https://cache.nixos.org" "https://nix-community.cachix.org" ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  environment.etc."ssh/ssh_known_hosts".text = ''
    github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
  '';

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  nix.optimise.automatic = true;

  services.journald.extraConfig = ''
    SystemMaxUse=200M
    RuntimeMaxUse=100M
  '';

  boot.tmp.cleanOnBoot = true;
}
