# modules/users.nix  (only the mkOne and surrounding let changed)
{ lib, pkgs, config, release, ... }:
let
  registry = import ../users/default.nix;
  toShell = s: if s == "zsh" then pkgs.zsh else pkgs.bashInteractive;
  anyZsh =
    lib.any (u: (u.shell or "bash") == "zsh") (builtins.attrValues registry);

  mkOne = name: u:
    let
      defaultKeyFile = ../users/keys/${name}.pub;
      keyFileExists = builtins.pathExists defaultKeyFile;
      keyFromFile =
        if keyFileExists then builtins.readFile defaultKeyFile else "";

      hasPasswordSecret = u ? passwordSecret; # only when explicitly provided
      hasInitialPw = u ? initialPassword; # optional plain-text bootstrap
      hasRoles = u ? roles && u.roles != { };
      hmOptIn = u ? homeManaged && u.homeManaged; # optional manual override
    in {
      # Only create an age secret if passwordSecret is provided in the user file
      # e.g., users/people/bas.nix has passwordSecret = ../../secrets/bas-password.age;
    } // lib.optionalAttrs hasPasswordSecret {
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
      }
      # If passwordSecret was given, wire hashedPasswordFile
        // lib.optionalAttrs hasPasswordSecret {
          hashedPasswordFile = config.age.secrets."${name}-password".path;
        }
        # If an initialPassword was given, wire it (plain text; stored in Nix store)
        // lib.optionalAttrs (hasInitialPw && !hasPasswordSecret) {
          initialPassword = u.initialPassword;
        };

    } // lib.optionalAttrs (hasRoles || hmOptIn) {
      home-manager.users.${name} = { ... }: {
        imports = [ ../home/default.nix ];
        home.username = name;
        home.homeDirectory = "/home/${name}";
        home.stateVersion = release;
        roles = u.roles or { };
      };
    };
in {
  imports = [ ../modules/base.nix ];

  config = lib.mkMerge ([
    # Ensure a primary group for every user at eval time
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
  ] ++ lib.mapAttrsToList mkOne registry);
}
