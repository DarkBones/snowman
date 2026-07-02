# Pure helpers for resolving which Home Manager roles apply to a user on a host.
#
# Two inventory schemas are supported:
#
#   Legacy (user-level enablement + per-host allowlist):
#     users.<u>.roles.<r>.enable = true;
#     hosts.<h>.availableRoles = [ "r" ... ];   # optional filter
#
#   Host-scoped (explicit binding per host, payload on the user):
#     hosts.<h>.roles.<u> = [ "r1" "r2" ... ];
#     users.<u>.roleConfig.<r> = { ... };       # optional per-role settings
#
# When a host defines `roles`, the host-scoped schema wins for that host.
# If legacy fields are also present, `dualMismatch` reports any disagreement
# so callers can assert the migration is consistent.
{ lib }:
rec {
  # Legacy resolution: enabled user roles, filtered by host.availableRoles.
  resolveLegacy =
    { host, user }:
    let
      userRoles = user.roles or { };
      enabled = lib.filterAttrs (_: rc: rc ? enable && rc.enable) userRoles;
      filterList = host.availableRoles or null;
    in
    if filterList == null then enabled else lib.filterAttrs (n: _: lib.elem n filterList) enabled;

  # Host-scoped resolution: the host binds role names per user; per-role
  # configuration payload comes from users.<u>.roleConfig.<r>.
  resolveHostScoped =
    {
      host,
      user,
      userName,
    }:
    let
      bound = (host.roles or { }).${userName} or [ ];
      payload = user.roleConfig or { };
    in
    builtins.listToAttrs (
      map (r: {
        name = r;
        value = (payload.${r} or { }) // {
          enable = true;
        };
      }) bound
    );

  hostUsesHostScoped = host: host ? roles;

  # Resolve roles for one user on one host, preferring the host-scoped schema.
  resolve =
    {
      host,
      user,
      userName,
    }:
    if hostUsesHostScoped host then
      resolveHostScoped { inherit host user userName; }
    else
      resolveLegacy { inherit host user; };

  # All role names any user is bound to on this host (host-scoped), or the
  # legacy availableRoles list, or null if neither is declared.
  hostRoleNames =
    host:
    if hostUsesHostScoped host then
      lib.unique (lib.concatLists (lib.attrValues host.roles))
    else
      host.availableRoles or null;

  # During migration both schemas may coexist. Returns null when they agree
  # (or when only one schema is in use), otherwise a human-readable summary.
  dualMismatch =
    {
      host,
      user,
      userName,
    }:
    let
      legacyPresent = (user.roles or { }) != { } || host ? availableRoles;
    in
    if !(hostUsesHostScoped host) || !legacyPresent then
      null
    else
      let
        legacy = resolveLegacy { inherit host user; };
        scoped = resolveHostScoped { inherit host user userName; };
        legacyNames = builtins.attrNames legacy;
        scopedNames = builtins.attrNames scoped;
        onlyLegacy = lib.subtractLists scopedNames legacyNames;
        onlyScoped = lib.subtractLists legacyNames scopedNames;
        payloadDiff = builtins.filter (n: legacy.${n} != scoped.${n}) (
          lib.intersectLists legacyNames scopedNames
        );
      in
      if onlyLegacy == [ ] && onlyScoped == [ ] && payloadDiff == [ ] then
        null
      else
        "legacy-only roles: [${toString onlyLegacy}]; host-scoped-only roles: [${toString onlyScoped}]; differing payloads: [${toString payloadDiff}]";
}
