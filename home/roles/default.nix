{ ... }:
let
  entries = builtins.readDir ./.;
  nixFiles = builtins.filter (n:
    entries.${n} == "regular" && builtins.match "^[^_].*\\.nix$" n != null && n
    != "default.nix") (builtins.attrNames entries);
in { imports = map (n: ./. + "/${n}") nixFiles; }
