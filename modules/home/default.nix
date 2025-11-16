{ pkgsUnstable, config, ... }: {
  imports = [
    ./roles/ssh.nix
    ./roles/dotfiles.nix
    ./roles/secrets.nix
    ./from-inventory.nix
  ];

  # config = { home.packages = with pkgsUnstable; [ neofetch ]; };
}
