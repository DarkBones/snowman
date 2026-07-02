# Changelog

Contract-relevant changes to the Snowman engine. Body repos should read this
before updating their `snowman` flake input.

## Unreleased (branch: fable)

### Fixed
- **Template:** `template/home/overrides/dev-dotfiles.nix` defined
  `home.activation.dotfilesSync` twice in one attrset, which is a Nix parse
  error. Freshly created body repos were broken as soon as the home overrides
  were imported.
- **`snowman` CLI:** the default flake path written to `/etc/snowman/flake`
  used to be the engine repo's own store path — a flake with no
  `nixosConfigurations`, so every command failed unless `SNOWMAN_FLAKE` was
  exported. The CLI now requires an explicit source: set the new
  `snowman.flakePath` option in your body config (recommended) or export
  `SNOWMAN_FLAKE`.

### Added
- **`snowman.flakePath` option** (string): path to the body flake the
  `snowman` CLI operates on. Written to `/etc/snowman/flake`.
- **`snowman secrets ...` subcommand**: delegates to
  `<flake>/bin/snowman-secrets-doctor` in the body repo when present.
- **Host-scoped role schema** (dual-read migration):
  - New: `hosts.<h>.roles.<user> = [ "role" ... ]` binds roles per host;
    `users.<u>.roleConfig.<role> = { ... }` carries per-role settings.
  - Legacy `users.<u>.roles.<r>.enable` + `hosts.<h>.availableRoles` still
    works. When a host defines the new `roles` attribute, the new schema wins;
    if legacy fields are also present, an assertion requires both schemas to
    resolve identically (guards half-finished migrations).
  - Resolution logic lives in `lib/roles.nix` and is exported as
    `snowman.lib.roles` from the flake so body flakes can reuse it for
    standalone `homeConfigurations` instead of duplicating the filter.
  - The resolved role names are exposed (internal) as
    `config.snowman.resolvedRoles.<user>` for migration diffing.
- **Secrets mode observability**: every activation writes
  `/var/lib/snowman/secrets-state.json` (host, usb-bootstrap vs
  rotated-host-key mode) and the USB key import logs its decisions to
  `/var/lib/snowman/usb-import.log`.

### Changed
- **Wi-Fi secrets are now scoped per host**: `wifi-<net>-password` sops
  secrets are only provisioned for networks listed in `hosts.<h>.wifi.networks`
  instead of for every network in the inventory. Hosts without Wi-Fi no longer
  need to be able to decrypt `networks/secrets.yml`.
