{ lib, currentHost, ... }:

let
  hostsDir = ../../../hosts; # TODO: Try with ../../hosts if not working
  hwFile = "${hostsDir}/${currentHost}-hardware-configuration.nix";
in {
  imports = lib.optional (builtins.pathExists hwFile) hwFile;

  assertions = [{
    assertion = builtins.pathExists hwFile;
    message = ''
      ❌ Snowman: Hardware configuration missing for host "${currentHost}".

      Expected file:
        hosts/${currentHost}-hardware-configuration.nix

      Fix:
        On the machine this NixOS install is running on, execute:

          ./bin/snowman-import-hardware ${currentHost}

        This will copy /etc/nixos/hardware-configuration.nix
        into the correct location in your Snowman config repo.

        Then re-run:

          sudo nixos-rebuild switch --flake .#${currentHost}
    '';
  }];
}
