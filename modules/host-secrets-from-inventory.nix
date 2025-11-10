{ inv, currentHost, lib, ... }:
let
  hasHost = builtins.hasAttr currentHost inv.hosts;
  host = if hasHost then inv.hosts.${currentHost} else { };
  secretsCfg = host.secrets or null;

  # We expect:
  # secrets = {
  #   sopsFile = ./hosts/secrets/vm-snowman.yml;
  #   items = {
  #     name = { key = "yaml.path"; owner = "..."; group = "..."; mode = "0400"; };
  #   };
  # };
  items = if secretsCfg == null then { } else (secretsCfg.items or { });

  mkSecret = name: spec: {
    # What sops-nix needs:
    sopsFile = secretsCfg.sopsFile;
    key = spec.key or name;
    format = "yaml";

    owner = spec.owner or "root";
    group = spec.group or "root";
    mode = spec.mode or "0400";
  };

  hostSecrets = if secretsCfg == null then { } else lib.mapAttrs mkSecret items;

in {
  options.snowman.hostSecrets = lib.mkOption {
    type = lib.types.attrsOf lib.types.attrs;
    default = { };
    description = "Per-host secrets derived from inventory (for sops-nix).";
    internal = true;
  };

  config = lib.mkMerge [
    # Only set anything if host is known AND secrets are configured
    (lib.mkIf (hasHost && secretsCfg != null) {
      snowman.hostSecrets = hostSecrets;
    })

    {
      assertions = [
        {
          assertion = !hasHost || secretsCfg == null || (secretsCfg ? sopsFile);
          message =
            "Host ${currentHost}: secrets.sopsFile must be set when secrets.items is used.";
        }
        {
          assertion = !hasHost || secretsCfg == null || (items != { });
          message =
            "Host ${currentHost}: secrets.items must not be empty when secrets is defined.";
        }
      ];
    }
  ];
}
