{ lib, ... }:
{
  options.snowman = {
    isRotated = lib.mkOption {
      type = lib.types.bool;
      default = false;
      internal = true;
      description = "True if the host key is present in .sops.yaml";
    };

    hostSecrets = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = { };
      internal = true;
      description = "Per-host secrets derived from inventory (for sops-nix).";
    };

    resolvedRoles = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = { };
      internal = true;
      description = "Enabled Home Manager role names per user, as resolved from the inventory. For diffing/migration tooling.";
    };
  };
}
