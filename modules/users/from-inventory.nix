{ inv, lib, pkgs, config, ... }:
let
  currentHost = config.networking.hostName;
  hostUsers = inv.hosts.${currentHost}.users;
  users = lib.filterAttrs (k: v: lib.elem k hostUsers) inv.users;
  namesAll = builtins.attrNames inv.users;
  unknown = lib.subtractLists namesAll hostUsers;
in {
  config.users.groups = lib.genAttrs (builtins.attrNames users) (_: { });

  config.assertions = [
    {
      assertion = unknown == [ ];
      message = "Inventory: host ${currentHost} lists unknown users: ${
          toString unknown
        }";
    }
    {
      assertion = builtins.isList hostUsers && builtins.length hostUsers > 0;
      message =
        "Inventory: `${currentHost}.users` must be a list of at least one username";
    }
  ];
}
