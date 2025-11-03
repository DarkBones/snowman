{ lib, pkgs, config, release, ... }:
let
  registry = import ../users/default.nix;
  toShell = s: if s == "zsh" then pkgs.zsh else pkgs.bashInteractive;
  anyZsh =
    lib.any (u: (u.shell or "bash") == "zsh") (builtins.attrValues registry);

  mkOne = name: u:
    let
      defaultSecret = ../secrets/${name}-password.age;
      defaultKeyFile = ../users/keys/${name}.pub;
      keyFileExists = builtins.pathExists defaultKeyFile;
      keyFromFile =
        if keyFileExists then builtins.readFile defaultKeyFile else "";
    in {
      users.groups.${name} = { };

      age.secrets."${name}-password".file = u.passwordSecret or defaultSecret;

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

        hashedPasswordFile = config.age.secrets."${name}-password".path;
      };

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
