# Standalone Home Manager configurations: one per host × user, including
# macOS machines that are not NixOS hosts. Role resolution comes from the
# engine (snowman.lib.roles); account-name remapping and role application
# happen in home/overrides/standalone-inventory.nix via the special args
# `homeAccountName` and `resolvedRoles`.
{
  lib,
  inputs,
  inv,
  sops-nix,
  snowman,
  dotfilesSources,
  makePkgs,
  makePkgsUnstable,
}:
let
  rolesLib = snowman.lib.roles;

  mkHome =
    hostName: user:
    let
      host = inv.hosts.${hostName};
      system = host.system or "x86_64-linux";
      cfgName = "${user}@${hostName}";

      # Resolve actual local username (for macOS aliases)
      localAccountNames = host.localAccountNames or { };
      actualUsername =
        if builtins.hasAttr user localAccountNames then localAccountNames.${user} else user;
      cfgNameActual = "${actualUsername}@${hostName}";

      finalRoles = rolesLib.resolve {
        inherit host;
        user = inv.users.${user};
        userName = user;
      };

      # Keep the dotfiles sourceKey pinned to the inventory name even when
      # home.username is remapped to a local account name.
      resolvedRoles =
        finalRoles
        // lib.optionalAttrs (finalRoles ? dotfiles) {
          dotfiles = finalRoles.dotfiles // {
            sourceKey = lib.mkDefault user;
          };
        };

      value = inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = makePkgs system;

        extraSpecialArgs = {
          inherit
            inputs
            inv
            sops-nix
            dotfilesSources
            resolvedRoles
            ;
          pkgsUnstable = makePkgsUnstable system;
          currentHost = hostName;
          hostRoles = rolesLib.hostRoleNames host;
          homeAccountName = actualUsername;
          sopsConfigPath = ../.sops.yaml;
          networkSecretsPath = ../networks/secrets.yml;
        };

        modules = [
          # On NixOS hosts the engine sets this from inv.release; standalone
          # configs need it set explicitly.
          { home.stateVersion = lib.mkDefault inv.release; }
          snowman.homeModules.default
          ../home/roles
          ../home/overrides
        ];
      };
    in
    [
      {
        name = cfgName;
        inherit value;
      }
    ]
    ++ (lib.optional (cfgName != cfgNameActual) {
      name = cfgNameActual;
      inherit value;
    });
in
lib.listToAttrs (
  lib.concatMap (
    hostName:
    let
      host = inv.hosts.${hostName};
      users = host.users or (builtins.attrNames inv.users);
    in
    lib.concatMap (mkHome hostName) users
  ) (builtins.attrNames inv.hosts)
)
