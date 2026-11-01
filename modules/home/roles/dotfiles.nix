{
  lib,
  config,
  pkgs,
  dotfilesSources ? { },
  ...
}:
let
  cfg = config.roles.dotfiles;

  hasSourceKey =
    cfg ? sourceKey && cfg.sourceKey != null && builtins.hasAttr cfg.sourceKey dotfilesSources;

  sourcePath = if hasSourceKey then builtins.getAttr cfg.sourceKey dotfilesSources else null;

  # Heuristic: detect SSH-style git remotes.
  # Covers:
  #   - ssh://host/path
  #   - user@host:org/repo.git   (incl. git@github.com:org/repo.git)
  isSshRemote =
    cfg.repo != ""
    && (lib.hasPrefix "ssh://" cfg.repo || (builtins.match "^[^@]+@[^:]+:.*" cfg.repo != null));

  # Every distinct path linkMap points at inside the repo.
  linkSources = lib.unique (lib.attrValues cfg.linkMap);

  # Pinned prod mode has the repo in the store, so eval can prove the paths
  # exist and fail the build. Dev and git mode resolve under $HOME, where pure
  # eval answers false for everything, so those are only checked at activation.
  pinnedEvalCheck = hasSourceKey && !config.dotfiles.isDev;

  missingPinnedSources = lib.optionals pinnedEvalCheck (
    lib.filter (src: !builtins.pathExists "${toString sourcePath}/${src}") linkSources
  );

in
{
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

  config = lib.mkIf cfg.enable (
    lib.mkMerge [

      # -------------------------------------------------------------------------
      # Shared: tooling + dependency declaration
      # -------------------------------------------------------------------------
      {
        # Tooling dotfiles needs in git mode
        home.packages = with pkgs; [
          git
          openssh
          inetutils
        ];

        # Dotfiles may require SSH; default it on, but allow explicit override.
        roles.ssh.enable = lib.mkDefault true;

        # A linkMap entry whose source does not exist still produces a symlink,
        # it just points at nothing. Check the sources up front so a typo or an
        # unpushed file fails loudly instead of leaving dead links in $HOME.
        # Always defined so the sync steps below can order against it.
        home.activation.dotfilesLinkMapVerify = lib.hm.dag.entryAfter [ "writeBoundary" ] (
          lib.optionalString (linkSources != [ ]) ''
            linkRoot=${lib.escapeShellArg config.dotfiles.root}
            missing=0

            for src in ${lib.escapeShellArgs linkSources}; do
              if [ ! -e "$linkRoot/$src" ]; then
                echo "[dotfiles] ERROR: linkMap source does not exist: $src" >&2
                missing=1
              fi
            done

            if [ "$missing" -ne 0 ]; then
              echo "[dotfiles] Resolved against $linkRoot" >&2
              echo "[dotfiles] Fix the path in linkMap, or update the dotfiles flake input if the file is new." >&2
              exit 1
            fi
          ''
        );

        assertions = [
          {
            assertion = missingPinnedSources == [ ];
            message = ''
              roles.dotfiles.linkMap points at paths that do not exist in the
              pinned dotfiles source (${toString sourcePath}):

              ${lib.concatMapStringsSep "\n" (src: "  - ${src}") missingPinnedSources}

              Fix the path in linkMap, or update the dotfiles flake input if the
              file exists locally but has not been pushed yet.
            '';
          }
          {
            assertion =
              # pinned mode -> no ssh needed
              hasSourceKey
              # git mode not configured -> no ssh needed
              || cfg.repo == ""
              # git mode with https -> ssh role optional
              || (!isSshRemote)
              # git mode with ssh -> ssh role must be enabled
              || (config.roles.ssh.enable or false);
            message = ''
              roles.dotfiles is configured to use an SSH git remote (${cfg.repo}),
              but roles.ssh.enable is false.

              Fix:
                - set roles.ssh.enable = true; OR
                - use an https remote for roles.dotfiles.repo.
            '';
          }
        ];
      }

      # -------------------------------------------------------------------------
      # Reproducible mode: use flake input (store path)
      # -------------------------------------------------------------------------
      (lib.mkIf hasSourceKey {
        home.activation.dotfilesSync =
          lib.hm.dag.entryAfter
            [
              "writeBoundary"
              "dotfilesLinkMapVerify"
            ]
            ''
              set -euo pipefail

              REPO_PATH=${lib.escapeShellArg (toString sourcePath)}

              if [ ! -d "$REPO_PATH" ]; then
                echo "[dotfiles] ERROR: source path '$REPO_PATH' is not a directory."
                exit 1
              fi

              echo "[dotfiles] Using pinned dotfiles from $REPO_PATH (flake input)."

              # Symlink targets from linkMap
              ${lib.concatStringsSep "\n" (
                lib.mapAttrsToList (target: src: ''
                  echo "[dotfiles] Linking ${target} -> ${src}"
                  mkdir -p "$(dirname "$HOME/${target}")"
                  rm -rf "$HOME/${target}"
                  ln -s "$REPO_PATH/${src}" "$HOME/${target}"
                '') cfg.linkMap
              )}
            '';
      })

      # -------------------------------------------------------------------------
      # Git mode: fall back to git clone/pull at activation time
      # -------------------------------------------------------------------------
      (lib.mkIf (!hasSourceKey) {
        programs.ssh.enable = true;

        home.activation.dotfilesSync =
          lib.hm.dag.entryAfter
            [
              "writeBoundary"
              "dotfilesLinkMapVerify"
            ]
            ''
              set -euo pipefail

              export PATH="${pkgs.openssh}/bin:${pkgs.git}/bin:$PATH"

              REPO=${lib.escapeShellArg cfg.repo}
              BRANCH=${lib.escapeShellArg cfg.branch}
              DIR=${lib.escapeShellArg cfg.dir}
              HOME_DIR=${lib.escapeShellArg config.home.homeDirectory}

              if [ -z "$REPO" ]; then
                echo "[dotfiles] WARNING: roles.dotfiles.repo is empty and no sourceKey is set; skipping."
                exit 0
              fi

              git="${pkgs.git}/bin/git"

              case "$DIR" in
                "~/"*)
                  DIR_REAL="$HOME_DIR/''${DIR#~/}"
                  ;;
                /*)
                  DIR_REAL="$DIR"
                  ;;
                *)
                  DIR_REAL="$HOME_DIR/$DIR"
                  ;;
              esac

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

              # Symlink targets from linkMap
              ${lib.concatStringsSep "\n" (
                lib.mapAttrsToList (target: src: ''
                  echo "[dotfiles] Linking ${target} -> ${src}"
                  mkdir -p "$(dirname "$HOME/${target}")"
                  rm -rf "$HOME/${target}"
                  ln -s "$DIR_REAL/${src}" "$HOME/${target}"
                '') cfg.linkMap
              )}
            '';
      })
    ]
  );
}
