# TODO: Make easier to configure
{ config, pkgs, ... }: {
  imports = [
    (import ../modules/security/user-password.nix {
      username = "bas";
      secretPath = ../secrets/bas-password.age;
      enable = true;
    })
  ];

  users.groups.bas = { };

  users.users.bas = {
    isNormalUser = true;
    group = "bas";
    extraGroups = [ "wheel" ];
    shell = pkgs.bashInteractive; # TODO: Consider zsh
    openssh.authorizedKeys.keys = [ (builtins.readFile ../keys/bas.pub) ];
  };

  home-manager.users.bas = import ../home/bas.nix;

  age.secrets."dotfiles-deploy-key" = {
    file = ../secrets/dotfiles-deploy-key.age;
    owner = "bas";
    group = "bas";
    mode = "0400";
  };

  programs.ssh = {
    startAgent = true;
    extraConfig = ''
      Host github-dotfiles
        HostName github.com
        User git
        IdentitiesOnly yes
        IdentityFile ~/.ssh/id_github_dotfiles
    '';
  };
}
