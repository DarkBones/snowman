{ osConfig, lib, ... }:
let
  maybe =
    name: if lib.hasAttr name osConfig.sops.secrets then osConfig.sops.secrets.${name}.path else "";

  vars = rec {
    EDITOR = "nvim";
    LANG = "en_US.UTF-8";

    # Example paths. Replace these if you actually use them.
    SNOWMAN_BASE_PATH = "$HOME/Developer/snowman";
    SNOWMAN_CONFIG_PATH = "$HOME/snowman-config";

    # Used by the `snowman` helper to override which body repo flake it targets.
    SNOWMAN_FLAKE = SNOWMAN_CONFIG_PATH;

    TEST_SECRET_PATH = maybe "test_secret";
  };
in
{
  home.sessionVariables = vars;

  systemd.user.sessionVariables = vars;
}
