{ lib, pkgsUnstable, dotfilesSources, inv, currentHost, disko, ... }:
let
  hasHost = builtins.hasAttr currentHost inv.hosts;
  host = if hasHost then inv.hosts.${currentHost} else { };
  diskoOn = host.provision.disk.enable or false;

  here = ./.;
  entries = builtins.readDir here;

  nixFiles = builtins.filter (name:
    entries.${name} == "regular" && lib.hasSuffix ".nix" name && name
    != "default.nix") (builtins.attrNames entries);

  moduleFiles = map (name: here + "/${name}") nixFiles;

in {
  imports = [
    ./hardware/from-inventory.nix
    ./home/from-inventory.nix
    ./storage/rootfs-from-inventory.nix
    ./users/from-inventory.nix
  ] ++ moduleFiles ++ lib.optional diskoOn disko.nixosModules.disko;

  config = {
    home-manager.extraSpecialArgs = { inherit pkgsUnstable dotfilesSources; };
  };
}
