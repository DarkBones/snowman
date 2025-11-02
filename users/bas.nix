{ config, pkgs, ... }: {
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

  age.secrets."dotfiles-deploy-key" = {
    file = ../secrets/dotfiles-deploy-key.age;
    owner = "bas";
    group = "bas";
    mode = "0440";
  };

  programs.ssh = {
    startAgent = true;
    extraConfig = ''
      Host github-dotfiles
        HostName github.com
        User git
        IdentitiesOnly yes
        IdentityFile ${config.age.secrets."dotfiles-deploy-key".path}
    '';
  };
}
