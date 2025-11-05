{ lib, pkgs, config, release, snowmanInventory ? { }, ... }:
let toShell = s: if s == "zsh" then pkgs.zsh else pkgs.bashInteractive;
in {
  config = let
    inv = snowmanInventory;

    registry = if inv ? users then inv.users else import ../users/default.nix;

    anyZsh =
      lib.any (u: (u.shell or "bash") == "zsh") (builtins.attrValues registry);

    # per-user: ONLY the system user + optional age secret/initial pw
    mkSystemUser = name: u:
      let
        defaultKeyFile = ../users/keys/${name}.pub;
        keyFileExists = builtins.pathExists defaultKeyFile;
        keyFromFile =
          if keyFileExists then builtins.readFile defaultKeyFile else "";
        hasPasswordSecret = (u ? passwordSecret);
        hasInitialPw = (u ? initialPassword);
      in { } // lib.optionalAttrs hasPasswordSecret {
        age.secrets."${name}-password".file = u.passwordSecret;
      } // {
        users.users.${name} = {
          isNormalUser = true;
          createHome = true;
          uid = lib.mkDefault (u.uid or null);
          group = name;
          extraGroups = u.groups or [ ];
          shell = toShell (u.shell or "bash");
          openssh.authorizedKeys.keys = (u.sshPubKeys or [ ])
            ++ (lib.optionals (u ? sshPubKeyFile)
              [ (builtins.readFile u.sshPubKeyFile) ])
            ++ (lib.optional keyFileExists keyFromFile);
        } // lib.optionalAttrs hasPasswordSecret {
          hashedPasswordFile = config.age.secrets."${name}-password".path;
        } // lib.optionalAttrs (hasInitialPw && !hasPasswordSecret) {
          initialPassword = u.initialPassword;
        };
      };

    needsHM = u:
      ((u ? roles) && ((u.roles or { }) != { }))
      || ((u ? homeManaged) && (u.homeManaged or false));

    mkHM = name: u:
      lib.mkIf (needsHM u) {
        home-manager.users.${name} = { ... }: {
          imports = [ ../home/default.nix ];
          home.username = name;
          home.homeDirectory = "/home/${name}";
          home.stateVersion = release;
          roles = u.roles or { };
        };
      };
  in lib.mkMerge ([
    { users.groups = lib.genAttrs (builtins.attrNames registry) (_: { }); }

    {
      system.activationScripts.ensureHmProfiles = {
        deps = [ "users" ];
        text = lib.concatStringsSep "\n" (map (u: ''
          if id -u ${u} >/dev/null 2>&1; then
            install -d -m 0755 -o ${u} -g ${u} /nix/var/nix/profiles/per-user/${u}
            install -d -m 0755 -o ${u} -g ${u} /home/${u}/.local/state/nix/profiles
          fi
        '') (builtins.attrNames registry));
      };
    }

    (lib.mkIf anyZsh { programs.zsh.enable = true; })
  ] ++ lib.mapAttrsToList mkSystemUser registry
    ++ lib.mapAttrsToList mkHM registry);
}
