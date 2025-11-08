{ inv, lib, pkgs, currentHost, options, config, ... }:
let
  hasHost = builtins.hasAttr currentHost inv.hosts;
  hostUsers = if hasHost then inv.hosts.${currentHost}.users else [ ];

  users = lib.filterAttrs (k: v: lib.elem k hostUsers) inv.users;
  declaredUserNames = builtins.attrNames inv.users;

  # YES, This is the correct order. The doccumentation is wrong.
  unknownUsers = lib.subtractLists declaredUserNames hostUsers;

  shellStrs =
    lib.unique (map (u: (u.shell or "bash")) (builtins.attrValues users));
  shellPkgs = lib.unique (lib.filter lib.isDerivation
    (map (u: toShell (u.shell or "bash")) (builtins.attrValues users)));
  enableFragments = map (s:
    lib.mkIf
    (s != "bash" && lib.hasAttrByPath [ "programs" s "enable" ] options)
    (lib.setAttrByPath [ "programs" s "enable" ] true)) shellStrs;

  toShell = s:
    let v = if s == null then "bash" else s;
    in if lib.isDerivation v then
      v
    else if lib.isString v && lib.hasPrefix "/" v then
      v
    else if v == "bash" then
      pkgs.bashInteractive
    else if builtins.hasAttr v pkgs then
      builtins.getAttr v pkgs
    else
      throw "Unknown shell '${
        toString v
      }'. Use a nixpkgs attribute name (e.g. 'fish', 'zsh', 'nushell') or an absolute path.";

  keysFor = u:
    (u.sshPubKeys or [ ])
    ++ (if (u ? sshPubKeyFile) && builtins.pathExists u.sshPubKeyFile then
      [ (builtins.readFile u.sshPubKeyFile) ]
    else
      [ ]);
in {
  config = lib.mkMerge ([{
    users.groups = lib.genAttrs (builtins.attrNames users) (_: { });
    users.mutableUsers =
      if hasHost then inv.hosts.${currentHost}.mutableUsers or true else false;
    environment.shells = shellPkgs ++ lib.unique
      (lib.filter (v: lib.isString v && lib.hasPrefix "/" v)
        (map (u: u.shell or "bash") (builtins.attrValues users)));
  }] ++ enableFragments ++ [
    {
      users.users = lib.mapAttrs (name: u: {
        isNormalUser = true;
        uid = u.uid;
        group = name;
        extraGroups = u.groups or [ ];
        shell = toShell (u.shell or "bash");
        openssh.authorizedKeys.keys = keysFor u;
      }) users;
    }

    (lib.mkMerge (lib.mapAttrsToList (name: u:
      let
        hasSecret = u ? passwordSecret;
        hasInitial = u ? initialPassword;
      in lib.mkMerge [
        (lib.optionalAttrs hasSecret {
          age.secrets."${name}-password".file = u.passwordSecret;
        })

        (lib.optionalAttrs hasSecret {
          users.users.${name}.hashedPasswordFile =
            config.age.secrets."${name}-password".path;
        } // lib.optionalAttrs (!hasSecret && hasInitial) {
          users.users.${name}.initialPassword = u.initialPassword;
        })

        {
          assertions = [
            {
              assertion = !(hasSecret && hasInitial);
              message =
                "Inventory: user ${name} sets BOTH passwordSecret and initialPassword.";
            }
            {
              assertion =
                config.services.openssh.settings.PasswordAuthentication == false
                || hasSecret || hasInitial;
              message =
                "SSH allows passwords but ${name} has neither passwordSecret nor initialPassword.";
            }
          ];
        }
      ]) users))
    {
      assertions = [
        {
          assertion = hasHost;
          message = "Inventory: host ${currentHost} not found in inv.hosts";
        }
        {
          assertion = unknownUsers == [ ];
          message = "Inventory: host ${currentHost} lists unknown users: ${
              toString unknownUsers
            }";
        }
        {
          assertion = builtins.length hostUsers > 0;
          message =
            "Inventory: `${currentHost}.users` must be a non-empty list";
        }
        {
          assertion = lib.all (n: (lib.length (keysFor users.${n})) > 0)
            (builtins.attrNames users);
          message = "Inventory: each user must provide at least one SSH key";
        }
        {
          assertion = lib.all (n:
            let v = users.${n}.shell or "bash";
            in !(lib.isString v && lib.hasPrefix "/" v))
            (builtins.attrNames users);
          message =
            "Inventory: user shells must be nixpkgs package names (not absolute paths).";
        }
      ];
    }
  ]);
}
