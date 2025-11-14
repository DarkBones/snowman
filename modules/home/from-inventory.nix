{ inv, currentHost, lib, ... }:
let hasHost = builtins.hasAttr currentHost inv.hosts;
in if !hasHost then
  { }
else
  let
    hostUsers = if hasHost then inv.hosts.${currentHost}.users else [ ];
    selected =
      lib.filterAttrs (n: u: lib.elem n hostUsers && (u.homeManaged or false))
      inv.users;
  in {
    config = {
      home-manager.users = lib.genAttrs (builtins.attrNames selected) (name:
        let u = selected.${name};
        in {
          imports = [ ./default.nix ] ++ lib.optional (u ? envFile) u.envFile;

          home = {
            username = name;
            homeDirectory = "/home/${name}";
            stateVersion = inv.release;
          };

          programs.home-manager.enable = true;
          systemd.user.startServices = false;
          roles = u.roles or { };
        });

      assertions = lib.mapAttrsToList (name: u: {
        assertion = !(u ? envFile) || builtins.pathExists u.envFile;
        message =
          "User ${name}: envFile '${toString u.envFile}' does not exist.";
      }) selected;
    };
  }
