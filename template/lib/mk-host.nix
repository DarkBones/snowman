# Builds one NixOS host from the inventory: engine wiring, Home Manager
# integration, and a hardware-config safety net. Called from flake.nix as
# `lib.mapAttrs mkHost inv.hosts`.
{
  lib,
  nixpkgs,
  home-manager,
  sops-nix,
  snowman,
  inv,
  dotfilesSources,
  makePkgsUnstable,
}:
let
  mkNixosSpecialArgs = name: attrs: {
    inherit
      home-manager
      inv
      sops-nix
      dotfilesSources
      ;
    pkgsUnstable = makePkgsUnstable attrs.system;
    modulesPath = "${nixpkgs}/nixos/modules";
    currentHost = name;
    sopsConfigPath = ../.sops.yaml;
    networkSecretsPath = ../networks/secrets.yml;
    extraHomeImports = [
      ../home/roles
      ../home/overrides
    ];
  };
in
name: attrs:
let
  host = inv.hosts.${name};
  hostName = host.hostname or name;
  hwFile = ../hosts/${hostName}-hardware-configuration.nix;
in
lib.nixosSystem {
  system = attrs.system;
  specialArgs = mkNixosSpecialArgs name attrs;
  modules = [
    # Snowman engine
    snowman.nixosModules.default

    # Home Manager integration
    home-manager.nixosModules.home-manager

    # This keeps the first install safe:
    # - import hardware if it exists
    # - fail with a clear message if you forgot to import it
    (
      { lib, ... }:
      {
        imports = lib.optional (builtins.pathExists hwFile) hwFile;

        assertions = [
          {
            assertion = builtins.pathExists hwFile;
            message = ''
              ❌ Snowman: Hardware configuration missing for host "${name}"
                 (hostname "${hostName}").

              Expected file:
                hosts/${hostName}-hardware-configuration.nix

              Fix:
                On the machine this NixOS install is running on, execute:

                  ./bin/snowman-import-hardware ${name}

                Then re-run:

                  sudo nixos-rebuild switch --flake .#${name}
            '';
          }
        ];
      }
    )
  ]
  ++ (attrs.extraModules or [ ]);
}
