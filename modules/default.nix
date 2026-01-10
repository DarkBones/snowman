{ lib, pkgs, pkgsUnstable, dotfilesSources, inv, currentHost, ... }:
let
  hasHost = builtins.hasAttr currentHost inv.hosts;

  here = ./.;
  entries = builtins.readDir here;

  nixFiles = builtins.filter (name:
    entries.${name} == "regular" && lib.hasSuffix ".nix" name && name
    != "default.nix" && name != "engine-inputs.nix" && name
    != "bootstrap-usb.nix" && name != "sops.nix") (builtins.attrNames entries);

  moduleFiles = map (name: here + "/${name}") nixFiles;

in {
  imports = [
    ./engine-inputs.nix
    ./bootstrap-usb.nix
    ./host-secrets-from-inventory.nix
    ./sops.nix

    ./hardware
    ./home/from-inventory.nix
    ./users
    ./compat.nix
  ] ++ moduleFiles;
} // lib.optionalAttrs hasHost {
  home-manager.extraSpecialArgs = { inherit pkgsUnstable dotfilesSources; };

  environment.systemPackages = (with pkgs; [ git age ])
    ++ [ pkgsUnstable.ssh-to-age ];
}
