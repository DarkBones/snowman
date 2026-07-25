# Applies inventory-derived settings when this config is built standalone
# (homeConfigurations): the local account name (macOS aliasing) and the
# resolved role set. Under NixOS-managed Home Manager these special args are
# absent and this module is a no-op.
args@{
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkMerge [
    (lib.optionalAttrs (args ? homeAccountName) {
      home.username = lib.mkDefault args.homeAccountName;
      home.homeDirectory = lib.mkDefault (
        if pkgs.stdenv.isDarwin then "/Users/${args.homeAccountName}" else "/home/${args.homeAccountName}"
      );
    })

    (lib.optionalAttrs (args ? resolvedRoles) {
      roles = args.resolvedRoles;
    })
  ];
}
