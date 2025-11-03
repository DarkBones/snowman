let
  dir = ./people;
  entries = builtins.readDir dir;
  nixFiles = builtins.filter
    (n: entries.${n} == "regular" && builtins.match ".*\\.nix$" n != null)
    (builtins.attrNames entries);

  load = name:
    let base = builtins.elemAt (builtins.match "^(.*)\\.nix$" name) 0;
    in {
      name = base;
      value = import (dir + "/${name}");
    };
in builtins.listToAttrs (map load nixFiles)
