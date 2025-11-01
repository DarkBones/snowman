{ lib, config, ... }: {
  options.snowman.base.present = lib.mkOption {
    type = lib.types.bool;
    default = false;
    internal = true;
  };
  config.assertions = [{
    assertion = config.snowman.base.present;
    message = "Snowman: modules/base.nix must be imported.";
  }];
}
