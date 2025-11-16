{ lib, pkgsUnstable, dotfilesSources, inv, currentHost, ... }:
let
  hasHost = builtins.hasAttr currentHost inv.hosts;
  host = if hasHost then inv.hosts.${currentHost} else { };

  here = ./.;
  entries = builtins.readDir here;

  nixFiles = builtins.filter (name:
    entries.${name} == "regular" && lib.hasSuffix ".nix" name && name
    != "default.nix") (builtins.attrNames entries);

  moduleFiles = map (name: here + "/${name}") nixFiles;

in {
  imports = [ ./hardware ./home ./users ] ++ moduleFiles;

  config = {
    home-manager.extraSpecialArgs = { inherit pkgsUnstable dotfilesSources; };
  };
}
