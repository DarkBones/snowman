{ pkgs, lib, config, ... }:
let cfg = config.roles.dev;
in {
  options.roles.dev = {
    enable = lib.mkEnableOption "Developer role (implies Neovim)";
    extraPackages = lib.mkOption {
      type = with lib.types; listOf package;
      default = [ ];
      description = "Extra dev packages beyond the Neovim toolchain.";
    };
  };

  config = lib.mkIf cfg.enable {
    roles.nvim.enable = true;

    programs.home-manager.enable = true;

    home.packages = with pkgs; [ tree lazygit openssh ] ++ cfg.extraPackages;

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
