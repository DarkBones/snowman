{ pkgs, ... }: {
  users.users.bas = {
    isNormalUser = true;
    shell = pkgs.bashInteractive; # TODO: Consider pkgs.zsh
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ (builtins.readFile ../keys/bas.pub) ];
  };

  home-manager.users.bas = import ../home/bas.nix;
}
