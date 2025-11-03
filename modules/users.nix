{ lib, pkgs, config, release, ... }:
let
  registry = import ../users/registry.nix;
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

      # Declare the secret path (defaults to ../secrets/<name>-password.age)
      age.secrets."${name}-password".file = u.passwordSecret or defaultSecret;

      users.users.${name} = {
        isNormalUser = true;
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
  config = lib.mkMerge ([ (lib.mkIf anyZsh { programs.zsh.enable = true; }) ]
    ++ lib.mapAttrsToList mkOne registry);
}
