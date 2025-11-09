{ osConfig, ... }: {
  home.sessionVariables = {
    EDITOR = "nvim";
    LANG = "en_US.UTF-8";
    FLAKE = "~/Developer/snowman";

    TEST_PATH = osConfig.sops.secrets.test.path;
  };
}
