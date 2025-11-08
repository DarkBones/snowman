{ lib, config, pkgs, ... }:
let cfg = config.roles.dotfiles;
in {
  options.roles.dotfiles = {
    enable = lib.mkEnableOption "Dotfiles role";

    repo = lib.mkOption {
      type = lib.types.str;
      description = "Git URL of the dotfiles repo (https or ssh).";
    };

    dir = lib.mkOption {
      type = lib.types.str;
      default = "dotfiles";
      description = "Target directory for cloning dotfiles";
    };

    branch = lib.mkOption {
      type = lib.types.str;
      default = "main";
      description = "Git branch to check out.";
    };

    sparse = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of paths for sparse checkout.";
    };

    linkMap = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Map: $HOME/<target> -> <path inside repo>.";
    };

    deployKeySecret = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Optional age-encrypted deploy key for private repos.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [ git openssh ];

    home.activation.dotfylesSync = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      set -euo pipefail

      export PATH="${pkgs.openssh}/bin:${pkgs.git}/bin:$PATH"

      REPO=${lib.escapeShellArg cfg.repo}
      BRANCH=${lib.escapeShellArg cfg.branch}
      DIR=${lib.escapeShellArg cfg.dir}

      git="${pkgs.git}/bin/git"

      mkdir -p "$DIR"

      if [ ! -d "$DIR/.git" ]; then
        echo "[dotfiles] Cloning $REPO into $DIR"
        $git clone --filter=blob:none --no-checkout "$REPO" "$DIR"
        $git -C "$DIR" sparse-checkout init --cone

        if [ ${toString (cfg.sparse != [ ])} = "1" ]; then
          $git -C "$DIR" sparse-checkout set ${lib.escapeShellArgs cfg.sparse}
        fi

        $git -C "$DIR" checkout "$BRANCH" || true
      else
        echo "[dotfiles] Updating repo in $DIR"
        $git -C "$DIR" fetch --prune || true
        $git -C "$DIR" switch "$BRANCH" || true
        $git -C "$DIR" pull --ff-only || true

        if [ ${toString (cfg.sparse != [ ])} = "1" ]; then
          $git -C "$DIR" sparse-checkout set ${lib.escapeShellArgs cfg.sparse}
        fi
      fi

      # symlink from linkMap
      DIR_REAL="$DIR"
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (target: src: ''
        echo "[dotfiles] Linking ${target} -> ${src}"
        mkdir -p "$(dirname "$HOME/${target}")"
        rm -rf "$HOME/${target}"
        ln -s "$DIR_REAL/${src}" "$HOME/${target}"
      '') cfg.linkMap)}
    '';
  };
}
