{ pkgsUnstable, config, ... }: {
  imports = [
    ./roles/ssh.nix
    ./roles/dotfiles.nix
    ./roles/secrets.nix
    ./roles/snowman.nix
  ];
}
