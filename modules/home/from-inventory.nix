{ inv, currentHost, lib, extraHomeImports ? [ ], ... }:
let hasHost = builtins.hasAttr currentHost inv.hosts;
in if !hasHost then
  { }
else
  let
    hostUsers =
      lib.filterAttrs (n: u: lib.elem n (inv.hosts.${currentHost}.users or [ ]))
      inv.users;
  in {
    config = {
      home-manager.users = lib.genAttrs (builtins.attrNames hostUsers) (name:
        let u = hostUsers.${name};
        in {
          imports = [ ./default.nix ] ++ extraHomeImports
            ++ lib.optional (u ? envFile) u.envFile;

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
      }) hostUsers;
    };
  }
