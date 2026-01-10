{ lib, config, pkgs, dotfilesSources ? { }, ... }:
let
  cfg = config.roles.dotfiles;

  hasSourceKey =
    (cfg ? sourceKey) &&
    (cfg.sourceKey != null) &&
    builtins.hasAttr cfg.sourceKey dotfilesSources;

  sourcePath =
    if hasSourceKey then builtins.getAttr cfg.sourceKey dotfilesSources else null;

  # Detect SSH-style git remotes:
  #   - ssh://host/path
  #   - user@host:org/repo.git   (incl. git@github.com:org/repo.git)
  isSshRemote =
    cfg.repo != "" &&
    (lib.hasPrefix "ssh://" cfg.repo || (builtins.match "^[^@]+@[^:]+:.*" cfg.repo != null));

  # Emit link operations as shell lines with safe quoting.
  mkLinkLines = repoVar: lib.concatStringsSep "\n" (lib.mapAttrsToList (target: src: ''
    echo "[dotfiles] Linking ${target} -> ${src}"
    link_atomic ${lib.escapeShellArg target} ${lib.escapeShellArg src} ${repoVar}
  '') cfg.linkMap);

in {
  options.roles.dotfiles = {
    enable = lib.mkEnableOption "Dotfiles role";

    sourceKey = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = config.home.username;
      description = ''
        Optional key into dotfilesSources (passed via extraSpecialArgs).
        If set and found, the repo is taken from the Nix store (flake input),
        and no git clone happens at activation time.
      '';
    };

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
    # -------------------------------------------------------------------------
    # Shared: tooling + assertions
    # -------------------------------------------------------------------------
    {
      home.packages = with pkgs; [ git openssh inetutils coreutils ];

      # Dotfiles may require SSH; default it on, but allow explicit override.
      roles.ssh.enable = lib.mkDefault true;

      assertions = [{
        assertion =
          hasSourceKey
          || cfg.repo == ""
          || (!isSshRemote)
          || (config.roles.ssh.enable or false);
        message = ''
          roles.dotfiles is configured to use an SSH git remote (${cfg.repo}),
          but roles.ssh.enable is false.

          Fix:
            - set roles.ssh.enable = true; OR
            - use an https remote for roles.dotfiles.repo.
        '';
      }];
    }

    # -------------------------------------------------------------------------
    # Pinned mode: use flake input (store path)
    # -------------------------------------------------------------------------
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

          link_atomic() {
            # Arguments:
            #   1 = target relative path
            #   2 = source relative path inside repo
            #   3 = repo root variable name (string, e.g. "REPO_PATH")
            local target_rel="$1"
            local src_rel="$2"
            local repo_var="$3"

            local repo_root
            repo_root="$(eval echo "\$$repo_var")"

            local target="$HOME/$target_rel"
            local source="$repo_root/$src_rel"
            local tmp="$target.hm-new"
            local backup="$target.hm-bak.$(date +%s)"

            mkdir -p "$(dirname "$target")"

            # Move aside existing target (best-effort)
            if [ -e "$target" ] || [ -L "$target" ]; then
              mv -Tf "$target" "$backup" 2>/dev/null || true
            fi

            rm -rf "$tmp"
            ln -s "$source" "$tmp"
            mv -Tf "$tmp" "$target"
          }

          ${mkLinkLines "REPO_PATH"}
        '';
    })

    # -------------------------------------------------------------------------
    # Git mode: clone/pull at activation time
    # -------------------------------------------------------------------------
    (lib.mkIf (!hasSourceKey) {
      programs.ssh.enable = true;

      home.activation.dotfilesSync =
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          set -euo pipefail

          export PATH="${pkgs.openssh}/bin:${pkgs.git}/bin:${pkgs.coreutils}/bin:$PATH"

          REPO=${lib.escapeShellArg cfg.repo}
          BRANCH=${lib.escapeShellArg cfg.branch}
          DIR=${lib.escapeShellArg cfg.dir}

          if [ -z "$REPO" ]; then
            echo "[dotfiles] WARNING: roles.dotfiles.repo is empty and no sourceKey is set; skipping."
            exit 0
          fi

          git="${pkgs.git}/bin/git"

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
              "$git" -C "$DIR_REAL" sparse-checkout set ${lib.escapeShellArgs cfg.sparse}
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

          echo "[dotfiles] Using git dotfiles repo at $DIR_REAL"

          link_atomic() {
            local target_rel="$1"
            local src_rel="$2"
            local repo_var="$3"

            local repo_root
            repo_root="$(eval echo "\$$repo_var")"

            local target="$HOME/$target_rel"
            local source="$repo_root/$src_rel"
            local tmp="$target.hm-new"
            local backup="$target.hm-bak.$(date +%s)"

            mkdir -p "$(dirname "$target")"

            if [ -e "$target" ] || [ -L "$target" ]; then
              mv -Tf "$target" "$backup" 2>/dev/null || true
            fi

            rm -rf "$tmp"
            ln -s "$source" "$tmp"
            mv -Tf "$tmp" "$target"
          }

          ${mkLinkLines "DIR_REAL"}
        '';
    })
  ]);
}
