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

    hostRoleFilter = hostCfg.availableRoles or null;
  in
  {
    config = {
      home-manager.users = lib.genAttrs (builtins.attrNames hostUsers) (
        name:
        let
          u = hostUsers.${name};

          userRoles = u.roles or { };

          # Only roles that are explicitly enabled
          enabledUserRoles = lib.filterAttrs (_: roleCfg: roleCfg ? enable && roleCfg.enable) userRoles;

          # If host.availableRoles is set, restrict to that list
          finalRoles =
            if hostRoleFilter == null then
              enabledUserRoles
            else
              lib.filterAttrs (roleName: _: lib.elem roleName hostRoleFilter) enabledUserRoles;
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
        (lib.mapAttrsToList (name: u: {
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
