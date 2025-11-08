{ inv, currentHost, lib, ... }:
let
  hasHost = builtins.hasAttr currentHost inv.hosts;
  hostUsers = if hasHost then inv.hosts.${currentHost}.users else [ ];
  selected =
    lib.filterAttrs (n: u: lib.elem n hostUsers && (u.homeManaged or false))
    inv.users;
in {
  assertions = [{
    assertion = hasHost;
    message = "Inventory: host ${currentHost} not found in inv.hosts";
  }];

  home-manager.users = lib.genAttrs (builtins.attrNames selected) (name: {
    imports = [ ./default.nix ];
    home.username = name;
    home.homeDirectory = "/home/${name}";
    home.stateVersion = inv.release;
    programs.home-manager.enable = true;
    systemd.user.startServices = false;
    roles = selected.${name}.roles or { };
  });
}
