{ inv, currentHost, lib, ... }:
let
  assertHost = builtins.hasAttr currentHost inv.hosts;
  hostUsers = if assertHost then inv.hosts.${currentHost}.users else [ ];
  selected = lib.filterAttrs (n: _: lib.elem n hostUsers) inv.users;
in {
  assertions = [{
    assertion = assertHost;
    message = "Inventory: host ${currentHost} not found in inv.hosts";
  }];

  home-manager.users = lib.genAttrs (builtins.attrNames selected) (name: {
    imports = [ ./default.nix ];
    home.username = name;
    home.homeDirectory = "/home/${name}";
    home.stateVersion = inv.release;
    programs.home-manager.enable = true;
    roles = selected.${name}.roles or { };
  });
}
