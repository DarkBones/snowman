{ lib, config, pkgs, dotfilesSources ? { }, ... }:
let
  cfg = config.roles.dotfiles;

  hasSourceKey = cfg ? sourceKey && cfg.sourceKey != null
    && builtins.hasAttr cfg.sourceKey dotfilesSources;

  sourcePath = if hasSourceKey then
    builtins.getAttr cfg.sourceKey dotfilesSources
  else
    null;

in {
  options.roles.dotfiles = {
    enable = lib.mkEnableOption "Dotfiles role";

    # Reproducible mode: look up this key in dotfilesSources
    sourceKey = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = config.home.username;
      description = ''
        Optional key into snowman/dotfilesSources (passed via extraSpecialArgs).
        If set and found, the repo is taken from the Nix store (flake input),
        and no git clone happens at activation time.
      '';
    };

    # Git mode: pull dotfiles at activation time (no locks, not reproducible)
    repo = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Git URL of the dotfiles repo (https or ssh).";
    };

    dir = lib.mkOption {
      type = lib.types.str;
      default = "dotfiles";
      description = "Target directory for cloning dotfiles (git mode).";
    };

    branch = lib.mkOption {
      type = lib.types.str;
      default = "main";
      description = "Git branch to check out (git mode).";
    };

    sparse = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of paths for sparse checkout (git mode).";
    };

    linkMap = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Map: $HOME/<target> -> <path inside repo>.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    # Git/ssh tools are only strictly needed in git mode
    {
      home.packages = with pkgs; [ git openssh ];
      programs.ssh.enable = true;
    }

    # --- Reproducible mode: use flake input (store path) ---
    (lib.mkIf hasSourceKey {
      home.activation.dotfilesSync =
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          set -euo pipefail

          REPO_PATH=${lib.escapeShellArg (toString sourcePath)}

          if [ ! -d "$REPO_PATH" ]; then
            echo "[dotfiles] ERROR: source path '$REPO_PATH' is not a directory."
            exit 1
          fi

          echo "[dotfiles] Using pinned dotfiles from $REPO_PATH (flake input)."

          # Symlink targets from linkMap
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList (target: src: ''
            echo "[dotfiles] Linking ${target} -> ${src}"
            mkdir -p "$(dirname "$HOME/${target}")"
            rm -rf "$HOME/${target}"
            ln -s "$REPO_PATH/${src}" "$HOME/${target}"
          '') cfg.linkMap)}
        '';
    })

    # --- Git mode: fall back to git clone/pull at activation time ---
    (lib.mkIf (!hasSourceKey) {
      home.activation.dotfilesSync =
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          set -euo pipefail

          export PATH="${pkgs.openssh}/bin:${pkgs.git}/bin:$PATH"

          keydir="$HOME/.ssh"
          keyfile="$keydir/id_ed25519"

          if [ ! -f "$keyfile" ]; then
            echo "[dotfiles] Generating SSH key at $keyfile"
            mkdir -p "$keydir"
            chmod 700 "$keydir"
            "${pkgs.openssh}/bin/ssh-keygen" \
              -t ed25519 \
              -N "" \
              -f "$keyfile" \
              -C "$USER@$("${pkgs.inetutils}/bin/hostname")"
          fi

          REPO=${lib.escapeShellArg cfg.repo}
          BRANCH=${lib.escapeShellArg cfg.branch}
          DIR=${lib.escapeShellArg cfg.dir}

          if [ -z "$REPO" ]; then
            echo "[dotfiles] WARNING: roles.dotfiles.repo is empty and no sourceKey is set; skipping."
            exit 0
          fi

          git="${pkgs.git}/bin/git"

          # Work in $HOME/<dir>
          DIR_REAL="$HOME/$DIR"
          mkdir -p "$DIR_REAL"

          update_repo() {
            if [ ! -d "$DIR_REAL/.git" ]; then
              echo "[dotfiles] Cloning $REPO into $DIR_REAL"
              "$git" clone --filter=blob:none --no-checkout "$REPO" "$DIR_REAL"
              "$git" -C "$DIR_REAL" sparse-checkout init --cone
            else
              echo "[dotfiles] Updating repo in $DIR_REAL"
            "$git" -C "$DIR_REAL" fetch --prune
            fi

            if [ ${toString (cfg.sparse != [ ])} = "1" ]; then
              "$git" -C "$DIR_REAL" sparse-checkout set ${
                lib.escapeShellArgs cfg.sparse
              }
            fi

            "$git" -C "$DIR_REAL" switch "$BRANCH" || \
              "$git" -C "$DIR_REAL" checkout -b "$BRANCH" "origin/$BRANCH" || true

            "$git" -C "$DIR_REAL" pull --ff-only || true
          }

          set +e
          update_repo
          status=$?
          set -e

          if [ "$status" -ne 0 ]; then
            echo "[dotfiles] WARNING: failed to sync repo (auth/network issue?). Skipping dotfiles."
            exit 0
          fi

          if [ ! -d "$DIR_REAL/.git" ]; then
            echo "[dotfiles] WARNING: $DIR_REAL is not a git repo; skipping link step."
            exit 0
          fi

          # Symlink targets from linkMap
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList (target: src: ''
            echo "[dotfiles] Linking ${target} -> ${src}"
            mkdir -p "$(dirname "$HOME/${target}")"
            rm -rf "$HOME/${target}"
            ln -s "$DIR_REAL/${src}" "$HOME/${target}"
          '') cfg.linkMap)}
        '';
    })
  ]);
}
