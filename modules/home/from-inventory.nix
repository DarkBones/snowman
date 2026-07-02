{
  inv,
  currentHost,
  lib,
  extraHomeImports ? [ ],
  ...
}:
let
  hasHost = builtins.hasAttr currentHost inv.hosts;
in
if !hasHost then
  { }
else
  let
    hostCfg = inv.hosts.${currentHost};
    hostUsers = lib.filterAttrs (
      n: u: lib.elem n (hostCfg.users or [ ]) && (u.homeManaged or false)
    ) inv.users;

    rolesLib = import ../../lib/roles.nix { inherit lib; };

    rolesFor =
      name:
      rolesLib.resolve {
        host = hostCfg;
        user = hostUsers.${name};
        userName = name;
      };

    # While both the legacy (users.<u>.roles + availableRoles) and the
    # host-scoped (hosts.<h>.roles.<u> + users.<u>.roleConfig) schemas are
    # present, they must agree. A mismatch means a half-finished migration.
    roleMigrationAssertions = lib.mapAttrsToList (
      name: u:
      let
        mismatch = rolesLib.dualMismatch {
          host = hostCfg;
          user = u;
          userName = name;
        };
      in
      {
        assertion = mismatch == null;
        message = "Snowman: role schema mismatch for user ${name} on host ${currentHost}: ${toString mismatch}";
      }
    ) hostUsers;
  in
  {
    config = {
      snowman.resolvedRoles = lib.mapAttrs (name: _: builtins.attrNames (rolesFor name)) hostUsers;

      home-manager.users = lib.genAttrs (builtins.attrNames hostUsers) (
        name:
        let
          u = hostUsers.${name};
          finalRoles = rolesFor name;
        in
        {
          imports = [ ./default.nix ] ++ extraHomeImports ++ lib.optional (u ? envFile) u.envFile;

          home = {
            username = name;
            homeDirectory = "/home/${name}";
            stateVersion = inv.release;
          };

          programs.home-manager.enable = true;
          systemd.user.startServices = false;

          roles = finalRoles;

          home.file = lib.mkIf (u ? face && u.face != null) {
            ".face".source = u.face;
            ".face.icon".source = u.face;
          };
        }
      );

      assertions =
        roleMigrationAssertions
        ++ (lib.mapAttrsToList (name: u: {
          assertion = !(u ? envFile) || builtins.pathExists u.envFile;
          message = "User ${name}: envFile '${toString u.envFile}' does not exist.";
        }) hostUsers)
        ++ [
          {
            assertion = (builtins.attrNames hostUsers) != [ ];
            message = ''
              Snowman: no home-managed users selected for host ${currentHost}.

              Fix: set users.<name>.homeManaged = true for at least one user on this host.
            '';
          }
        ];
    };
  }
