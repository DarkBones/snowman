{ lib, pkgsUnstable, pkgs, dotfilesSources, ... }:
let
  here = ./.;
  entries = builtins.readDir here;

  nixFiles = builtins.filter (name:
    entries.${name} == "regular" && lib.hasSuffix ".nix" name && name
    != "default.nix") (builtins.attrNames entries);

  moduleFiles = map (name: here + "/${name}") nixFiles;

in {
  imports = [ ./hardware ./home/from-inventory.nix ./users ] ++ moduleFiles;

  config = {
    home-manager.extraSpecialArgs = { inherit pkgsUnstable dotfilesSources; };

    environment.systemPackages = [ pkgs.git pkgsUnstable.ssh-to-age ];
  };
}
