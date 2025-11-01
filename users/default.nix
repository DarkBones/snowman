{ ... }:
let
  entries = builtins.readDir ./.;

  nixFiles = builtins.filter (name:
    entries.${name} == "regular" && builtins.match "^[^_].*\\.nix$" name != null
    && name != "default.nix") (builtins.attrNames entries);
in { imports = map (name: ./. + "/${name}") nixFiles; }
