{ lib, pkgs, config, ... }:
let
  registry = import ../users/registry.nix;
  toShell = s: if s == "zsh" then pkgs.zsh else pkgs.bashInteractive;
  anyZsh =
    lib.any (u: (u.shell or "bash") == "zsh") (builtins.attrValues registry);

  mkOne = name: u: {
    users.groups.${name} = { };

    # declare the secret path
    age.secrets."${name}-password".file = u.passwordSecret;

    # define the user once, include hashedPasswordFile inside
    users.users.${name} = {
      isNormalUser = true;
      uid = lib.mkDefault u.uid;
      group = name;
      extraGroups = u.groups or [ ];
      shell = toShell (u.shell or "bash");
      openssh.authorizedKeys.keys = (u.sshPubKeys or [ ])
        ++ (lib.optional (u ? sshPubKeyFile)
          (builtins.readFile u.sshPubKeyFile));

      hashedPasswordFile = config.age.secrets."${name}-password".path;
    };

    home-manager.users.${name} = { ... }: {
      imports = [ ../home/default.nix ];
      home.username = name;
      home.homeDirectory = "/home/${name}";
      home.stateVersion = "25.05";
      roles = u.roles or { };
    };
  };
in {
  imports = [ ../modules/base.nix ];

  config = lib.mkMerge ([ (lib.mkIf anyZsh { programs.zsh.enable = true; }) ]
    ++ lib.mapAttrsToList mkOne registry);
}
