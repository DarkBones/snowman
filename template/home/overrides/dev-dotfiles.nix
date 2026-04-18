{
  lib,
  config,
  dotfilesSources,
  ...
}:
let
  cfg = config.roles.dotfiles or { };
  root = config.dotfiles.root;

  sourceKey = cfg.sourceKey or config.home.username;
  dotfilesRepo = dotfilesSources.${sourceKey} or null;

  # Determine if we should replace the activation script
  # We do this if we are managing the files via home.file (Dev or Prod-Pinned)
  shouldReplaceScript = config.dotfiles.isDev || dotfilesRepo != null;

in
{
  config = lib.mkIf (cfg.enable or false) {

    # 1. Disable the Base activation script so it doesn't fight us
    # (Force-disable to ensure linkMap always wins)
    home.activation.dotfilesSync = lib.mkForce "";
    home.activation.dotfilesSync = lib.mkIf shouldReplaceScript (lib.mkForce "");

    # 2. Generate home.file entries
    home.file = lib.mapAttrs (
      _target: srcPath:
      if config.dotfiles.isDev then
        # Dev Mode: Home Manager creates a symlink to your resolved local checkout
        {
          source = config.lib.file.mkOutOfStoreSymlink "${root}/${srcPath}";
        }
      else if dotfilesRepo != null then
        # Prod Mode: Home Manager creates a symlink to the Nix Store
        {
          source = "${root}/${srcPath}";
        }
      else
        # Git Mode (Fallback): Do nothing, let the activation script handle it
        { }
    ) (cfg.linkMap or { });
  };
}
