{ pkgs, lib, config, ... }:
let cfg = config.roles.dev;
in {
  options.roles.dev.enable = lib.mkEnableOption "Dev role";
  config = lib.mkIf cfg.enable {
    programs.home-manager.enable = true;
    home.packages = with pkgs; [ git neovim ripgrep tree ];
    programs.direnv.enable = true;
    programs.direnv.nix-direnv.enable = true;

    home.activation.dotfilesAuthProbe =
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        set -euo pipefail
        repo="github-dotfiles:DarkBones/dotfiles.git"
        dir="$HOME/.local/share/dotfiles"

        echo "[probe] Testing GitHub auth via deploy key…"
        # Show which key is being offered (verbose, but only on failure we print it)
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
  };
}
