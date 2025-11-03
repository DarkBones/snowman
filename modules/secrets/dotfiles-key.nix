{ ... }: {
  age.secrets."dotfiles-deploy-key".file =
    ../../secrets/dotfiles-deploy-key.age;
}
