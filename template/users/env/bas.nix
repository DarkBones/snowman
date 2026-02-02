{ osConfig, lib, ... }:
let
  maybe = name:
    if lib.hasAttr name osConfig.sops.secrets then
      osConfig.sops.secrets.${name}.path
    else
      "";

  vars = {
    EDITOR = "nvim";
    LANG = "en_US.UTF-8";

    FLAKE = "$HOME/Developer/snowman";
    SNOWMAN_FLAKE = "$HOME/snowman-config";

    TEST_SECRET_PATH = maybe "test_secret";
  };
in {
  home.sessionVariables = vars;

  systemd.user.sessionVariables = vars;
}
