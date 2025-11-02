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

  # Home Manager config for bas
  home-manager.users.bas = import ../home/bas.nix;

  # Keep deploy key as a root-owned runtime secret; HM will copy it into ~/.ssh
  age.secrets."dotfiles-deploy-key" = {
    file = ../secrets/dotfiles-deploy-key.age;
    owner = "root";
    group = "wheel";
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
