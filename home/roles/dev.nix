{ pkgs, lib, config, ... }:
let cfg = config.roles.dev;
in {
  options.roles.dev.enable = lib.mkEnableOption "Dev role";

  config = lib.mkIf cfg.enable {
    programs.home-manager.enable = true;

    home.packages = with pkgs; [ git neovim ripgrep tree ];

    programs.direnv.enable = true;
    programs.direnv.nix-direnv.enable = true;

    # 1) Install the deploy key into the user's ~/.ssh AFTER the user exists.
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

    # 2) Probe auth and do first-time clone/fetch only AFTER key is placed.
    home.activation.dotfilesAuthProbe =
      lib.hm.dag.entryAfter [ "installDotfilesKey" ] ''
        set -euo pipefail
        repo="github-dotfiles:DarkBones/dotfiles.git"
        dir="$HOME/.local/share/dotfiles"

        echo "[probe] Testing GitHub auth via deploy key…"
        if ssh -o BatchMode=yes -T git@github-dotfiles 2>&1 | tee /tmp/ssh-probe.log; then
          echo "[probe] ssh handshake OK (GitHub will still say 'no shell')"
        else
          echo "[probe] ssh handshake failed (expected until you add the deploy key to GitHub)" >&2
          sed -n '1,80p' /tmp/ssh-probe.log >&2 || true
        fi

        if [ ! -d "$dir/.git" ]; then
          echo "[clone] First-time clone to $dir"
          mkdir -p "$dir"
          if git clone "$repo" "$dir"; then
            echo "[clone] success"
          else
            echo "[clone] failed (expected if key not yet added on GitHub)" >&2
            exit 0
          fi
        else
          echo "[update] Fetching latest in $dir"
          git -C "$dir" fetch --prune || true
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
