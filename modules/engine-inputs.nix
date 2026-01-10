{ lib, ... }: {
  options.snowman.engineInputs = lib.mkOption {
    type = lib.types.attrs;
    default = { };
    internal = true;
    description = "Snowman engine flake inputs";
  };
}
