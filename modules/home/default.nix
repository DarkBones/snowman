{ pkgsUnstable, config, ... }: {
  imports = [
    ./roles/dev.nix
    ./roles/ssh.nix
    ./roles/dotfiles.nix
    ./roles/secrets.nix
  ];

  # config = { home.packages = with pkgsUnstable; [ neofetch ]; };
}
