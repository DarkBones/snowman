{ pkgs, lib, config, ... }:
let cfg = config.roles.dev;
in {
  options.roles.dev.enable = lib.mkEnableOption "Dev role";

  config = lib.mkIf cfg.enable {
    programs.home-manager.enable = true;

    home.packages = with pkgs; [
      neovim
      tree
      gcc
      gnumake
      pkg-config
      unzip

      ripgrep
      fd
      fzf
      git
      nodejs_20
      python3
      wl-clipboard
      lazygit
    ];

    # 1) Install the deploy key
    home.activation.installDotfilesKey =
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        set -euo pipefail
        src='/run/agenix/dotfiles-deploy-key'
        dst="$HOME/.ssh/id_github_dotfiles"

        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh" || true

        if [ -r "$src" ]; then
          install -m 600 -o "$USER" -g "$USER" "$src" "$dst"
          echo "[key] installed ~/.ssh/id_github_dotfiles"
        else
          echo "[key] warning: $src not present yet (agenix not staged?)"
        fi
      '';

    programs.ssh.enable = true;
    programs.ssh.extraConfig = ''
      Host github-dotfiles
        HostName github.com
        User git
        IdentitiesOnly yes
        IdentityFile ~/.ssh/id_github_dotfiles
    '';
  };
}
