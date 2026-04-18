{
  lib,
  inv,
  currentHost,
  modulesPath,
  ...
}:
let
  hasHost = builtins.hasAttr currentHost inv.hosts;
  host = if hasHost then inv.hosts.${currentHost} else { };
  profiles = host.profiles or [ ];

  toProfilePath =
    profileName:
    if builtins.pathExists "${modulesPath}/profiles/${profileName}.nix" then
      "${modulesPath}/profiles/${profileName}.nix"
    else
      throw "Snowman: Unknown profile '${profileName}'";

in
{
  imports = lib.map toProfilePath profiles;

  config = { };
}
