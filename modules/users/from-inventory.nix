# modules/users/from-inventory.nix
{ inv, lib, pkgs, currentHost, options, config, ... }:
let
  hasHost = builtins.hasAttr currentHost inv.hosts;
  hostUsers = if hasHost then inv.hosts.${currentHost}.users else [ ];

  # Only users listed for this host
  users = lib.filterAttrs (k: v: lib.elem k hostUsers) inv.users;

  declaredUserNames = builtins.attrNames inv.users;

  # Yes, This is the correct order. The documentation is wrong. THIS IS NOT A BUG!
  unknownUsers = lib.subtractLists declaredUserNames hostUsers;

  # Shell handling --------------------------------------------------------------
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

  shellStrs =
    lib.unique (map (u: (u.shell or "bash")) (builtins.attrValues users));

  shellPkgs = lib.unique (lib.filter lib.isDerivation
    (map (u: toShell (u.shell or "bash")) (builtins.attrValues users)));

  enableFragments = map (s:
    lib.mkIf
      (s != "bash" && lib.hasAttrByPath [ "programs" s "enable" ] options)
      (lib.setAttrByPath [ "programs" s "enable" ] true)
  ) shellStrs;

  # SSH key collection ----------------------------------------------------------
  keysFor = u:
    let
      inlineKeys = u.sshPubKeys or [ ];

      filePaths = (lib.optional (u ? sshPubKeyFile) u.sshPubKeyFile)
        ++ (u.sshPubKeyFiles or [ ]);

      fileKeys = map builtins.readFile filePaths;
    in inlineKeys ++ fileKeys;

  sshKeyFileAssertions = lib.mapAttrsToList (name: u:
    let
      filePaths = (lib.optional (u ? sshPubKeyFile) u.sshPubKeyFile)
        ++ (u.sshPubKeyFiles or [ ]);
    in {
      assertion = lib.all builtins.pathExists filePaths;
      message =
        "Inventory: user ${name} references non-existent sshPubKeyFile(s): "
        + (toString (lib.filter (p: !builtins.pathExists p) filePaths));
    }) users;

in {
  options.snowman.meta = {
    host = lib.mkOption {
      type = lib.types.str;
      default = currentHost;
      description = "Inventory host name this system was built for.";
    };

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = builtins.attrNames users;
      description = "Users Snowman believes should exist on this host.";
    };
  };

  config = lib.mkMerge ([{
    users.groups = lib.genAttrs (builtins.attrNames users) (_: { });
    users.mutableUsers =
      if hasHost then inv.hosts.${currentHost}.mutableUsers or false else false;

    environment.shells = shellPkgs ++ lib.unique
      (lib.filter (v: lib.isString v && lib.hasPrefix "/" v)
        (map (u: u.shell or "bash") (builtins.attrValues users)));
  }] ++ enableFragments ++ [
    {
      # Basic user definitions ---------------------------------------------------
      users.users = lib.mapAttrs (name: u: {
        isNormalUser = true;
        uid = u.uid;
        group = name;
        extraGroups = u.groups or [ ];
        shell = toShell (u.shell or "bash");
        openssh.authorizedKeys.keys = keysFor u;
      }) users;
    }

    # Password selection (SOPS vs initialPassword) ------------------------------
    (lib.mkMerge (lib.mapAttrsToList (name: u:
      let
        hasInitial = u ? initialPassword;
        hasSopsPassword = (u ? secrets.sopsFile)
          && (u ? secrets.userPasswordHashKey)
          && lib.elem u.secrets.userPasswordHashKey (u.secrets.keys or [ ]);

        passwordKey =
          if hasSopsPassword then u.secrets.userPasswordHashKey else null;
      in lib.mkMerge [
        (lib.optionalAttrs hasSopsPassword {
          users.users.${name}.hashedPasswordFile =
            config.sops.secrets.${passwordKey}.path;
        })

        (lib.optionalAttrs (!hasSopsPassword && hasInitial) {
          users.users.${name}.initialPassword = u.initialPassword;
        })

        {
          assertions = [
            {
              assertion = !(hasSopsPassword && hasInitial);
              message =
                "Inventory: user ${name} sets BOTH SOPS password and initialPassword. Choose one.";
            }
            {
              assertion =
                config.services.openssh.settings.PasswordAuthentication == false
                || hasSopsPassword || hasInitial;
              message =
                "SSH allows passwords but ${name} has neither SOPS password nor initialPassword. Configure one.";
            }
            {
              assertion =
                !(hasHost && (inv.hosts.${currentHost}.mutableUsers or false))
                || (inv.hosts.${currentHost}.users or [ ]) == [ ];
              message = ''
                Inventory: host ${currentHost} has mutableUsers = true but also declares
                users in hosts.${currentHost}.users.

                With users.mutableUsers = true, NixOS will NOT create or manage any users,
                so those inventory users will never appear on the system.

                Either:
                  - remove mutableUsers (Snowman will default it to false), or
                  - set mutableUsers = false explicitly, or
                  - remove hosts.${currentHost}.users and manage users manually.
              '';
            }
          ];
        }
      ]) users))

    {
      assertions = sshKeyFileAssertions ++ [
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
          assertion = builtins.length (builtins.attrNames users) > 0;
          message = ''
            Snowman: resolved no users for host "${currentHost}".
            Check:
              - inv.hosts.${currentHost}.users
              - inv.users
          '';
        }
        {
          assertion = lib.all (name:
            let
              u = users.${name};

              hasInitial = u ? initialPassword;
              hasSopsPassword = (u ? secrets.sopsFile)
                && (u ? secrets.userPasswordHashKey)
                && lib.elem u.secrets.userPasswordHashKey
                (u.secrets.keys or [ ]);

              hasKeys = (lib.length (keysFor u)) > 0;
            in hasInitial || hasSopsPassword || hasKeys)
            (builtins.attrNames users);

          message = ''
            Inventory: each user must provide at least one login method:
              - SSH key (sshPubKeys / sshPubKeyFile / sshPubKeyFiles), or
              - password (initialPassword or secrets.userPasswordHashKey).
          '';
        }
      ];

      snowman.meta.host = currentHost;
      snowman.meta.users = builtins.attrNames users;
    }
  ]);
}
