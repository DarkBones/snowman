{ lib, pkgsUnstable, dotfilesSources, inv, currentHost, disko, ... }:
let
  hasHost = builtins.hasAttr currentHost inv.hosts;
  host = if hasHost then inv.hosts.${currentHost} else { };
  diskoOn = (host.provision.disk.enable or false);
in {
  imports = [
    ./hardware/from-inventory.nix
    ./home/from-inventory.nix
    ./storage/rootfs-from-inventory.nix
    ./users/from-inventory.nix
    ./bootstrap-usb.nix
    ./host-secrets-from-inventory.nix
    ./nix.nix
    ./security.nix
    ./sops.nix
    ./ssh.nix
    ./profiles.nix
  ] ++ lib.optional diskoOn disko.nixosModules.disko;

  config = {
    home-manager.extraSpecialArgs = { inherit pkgsUnstable dotfilesSources; };
  };
}
