{ inv, lib, pkgs, currentHost, options, ... }:
let
  hostUsers = inv.hosts.${currentHost}.users;
  users = lib.filterAttrs (k: v: lib.elem k hostUsers) inv.users;
  declaredUserNames = builtins.attrNames inv.users;
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
    users.mutableUsers = true;
    environment.shells = shellPkgs ++ lib.unique
      (lib.filter (v: lib.isString v && lib.hasPrefix "/" v)
        (map (u: u.shell or "bash") (builtins.attrValues users)));
  }] ++ enableFragments ++ [
    (lib.mkMerge (lib.mapAttrsToList (name: u: {
      users.users.${name} = {
        isNormalUser = true;
        uid = u.uid;
        group = name;
        extraGroups = u.groups or [ ];
        shell = toShell (u.shell or "bash");
        openssh.authorizedKeys.keys = keysFor u;
      } // (lib.optionalAttrs (u ? initialPassword) {
        initialPassword = u.initialPassword;
      });
    }) users))
    {
      assertions = [
        {
          assertion = builtins.hasAttr currentHost inv.hosts;
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
