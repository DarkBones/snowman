{ pkgsUnstable, config, ... }:
{
  imports = [
    ./overrides/default.nix
    ./roles/ssh.nix
    ./roles/dotfiles.nix
    ./roles/secrets.nix
    ./roles/snowman.nix
  ];
}
