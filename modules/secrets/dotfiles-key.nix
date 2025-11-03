{ ... }: {
  age.secrets."dotfiles-deploy-key" = {
    file = ../../secrets/dotfiles-deploy-key.age;
    owner = "bas";
    group = "bas";
    mode = "0400";
  };
}
