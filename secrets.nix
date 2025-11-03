let
  recipients = import ./hosts/age-recipients.nix;
  users = builtins.attrNames (import ./users/default.nix);
in (builtins.listToAttrs (map (u: {
  name = "secrets/${u}-password.age";
  value = { publicKeys = recipients; };
}) users)) // {
  "secrets/dotfiles-deploy-key.age".publicKeys = recipients;
}
