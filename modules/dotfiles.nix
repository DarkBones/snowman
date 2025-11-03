{ lib, config, pkgs, ... }:
let
  cfg = config.snowman.dotfiles;
  linkOne = target: srcRel: ''
    mkdir -p "$(dirname "$HOME/${target}")"
    rm -rf "$HOME/${target}"
    ln -s "$DIR/${srcRel}" "$HOME/${target}"
  '';
in {
  options.snowman.dotfiles = {
    enable = lib.mkEnableOption
      "Manage private dotfiles via deploy key + sparse checkout";
    repo = lib.mkOption {
      type = lib.types.str;
      default =
        "github-dotfiles:DarkBones/dotfiles.git"; # TODO: Make link configurable
    };
    branch = lib.mkOption {
      type = lib.types.str;
      default = "main";
    };
    dir = lib.mkOption {
      type = lib.types.str;
      default = "$HOME/.local/share/dotfiles";
    };
    sparse = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "nvim" ];
    };
    linkMap = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { ".config/nvim" = "nvim"; };
    };
  };

  config = lib.mkIf cfg.enable {
    xdg.enable = true;

    home.activation.dotfilesSync =
      lib.hm.dag.entryAfter [ "installDotfilesKey" ] ''
        set -euo pipefail
        REPO=${cfg.repo}
        BR=${cfg.branch}
        DIR=${cfg.dir}

        export PATH="${pkgs.openssh}/bin:$PATH"

        # Define the path to git
        git="${pkgs.git}/bin/git"

        if [ ! -d "$DIR/.git" ]; then
          mkdir -p "$DIR"
          $git clone --filter=blob:none --no-checkout "$REPO" "$DIR"
          $git -C "$DIR/" sparse-checkout init --cone
          
          # FIX: Use modern sparse-checkout set syntax
          $git -C "$DIR" sparse-checkout set ${lib.escapeShellArgs cfg.sparse}
          
          $git -C "$DIR" checkout "$BR" || $git -C "$DIR" checkout -b "$BR" "origin/$BR" || true
        else
          $git -C "$DIR" fetch --prune || true
          $git -C "$DIR" switch "$BR" || true
          $git -C "$DIR" pull --ff-only || true
          
          # FIX: Use modern sparse-checkout set syntax
          $git -C "$DIR" sparse-checkout set ${lib.escapeShellArgs cfg.sparse}
        fi

        $git -C "$DIR" config --global --replace-all safe.directory "$DIR" || true

        # Link requested items
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList linkOne cfg.linkMap)}
      '';
  };
}
