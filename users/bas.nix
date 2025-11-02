{ pkgs, ... }: {
  imports = [
    (import ../modules/security/user-password.nix {
      username = "bas";
      secretPath = ../secrets/bas-password.age;
      enable = true;
    })
  ];

  users.users.bas = {
    isNormalUser = true;
    shell = pkgs.bashInteractive;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ (builtins.readFile ../keys/bas.pub) ];
  };

  home-manager.users.bas = import ../home/bas.nix;
}
