# BEFORE RELEASE CHECKLIST

- [ ] Convert all existing encrypted secrets with bogus values
- [ ] Create kill-switch in case key is leaked
- [ ] Comment out bas-dotfiles flake input as an optional example over pulling dotfiles at activation time

# Snowman – minimal spine

This repo is a **NixOS spine** that:

- builds hosts from a central `inventory.nix`,
- provisions users and their home-manager configs,
- manages secrets via **sops-nix** (per-user),
- optionally bootstraps secrets using a **USB Age key** (“Snowman key”).

It’s meant to be **reproducible**, **host-agnostic**, and **inventory-driven**.

---

## ✅ Before release checklist

- [ ] All **sops secrets use bogus/demo values** (no real API keys or passwords).
- [ ] Each host in `inventory.nix` has:
  - [ ] `mutableUsers = false` if you want full declarative user mgmt.
  - [ ] Correct `hardware.*` and `provision.*` data.
- [ ] `.sops.yaml` includes **only the Age recipients you actually own**.
- [ ] USB bootstrap key is documented & safely backed up.

---

## 🔐 Secrets model (high level)

Snowman uses:

- **[sops](https://github.com/getsops/sops)** for editing encrypted YAML files.
- **[sops-nix](https://github.com/Mic92/sops-nix)** to decrypt them at boot.
- **Age** keys as recipients (some derived from SSH keys, some standalone).

Currently, secrets are:

- stored per-user in `users/secrets/<user>_secrets.yml`,
- encrypted according to rules in `.sops.yaml`,
- made available on the machine via `sops-nix`,
- wired into NixOS via the **nested** `secrets` attribute in `inventory.nix` (per user).

Later you can add per-host secrets with a similar pattern.

---

## 🧾 Per-user secrets files

### Where secrets live

For each user that needs secrets, you have:

```text
users/secrets/<name>_secrets.yml   # encrypted with sops
````

Example: `users/secrets/bas_secrets.yml`

The file is a YAML mapping of keys → secret values, e.g.:

```yaml
# users/secrets/bas_secrets.yml (edited via `sops`)
password_hash: "$y$j9T$..."    # e.g. mkpasswd --method=yescrypt
test: "some-random-test-secret"
github_pat: "ghp_..."
```

> 🔒 What’s actually committed is an encrypted blob; the above is just the logical shape.

### How it’s wired from inventory

In `inventory.nix` the **user** now has a nested `secrets` block:

```nix
users = {
  bas = {
    uid         = 1000;
    homeManaged = true;
    groups      = [ "wheel" ];
    shell       = "zsh";
    sshPubKeys  = [ (builtins.readFile ./users/keys/bas-arch.pub) ];

    secrets = {
      sopsFile            = ./users/secrets/bas_secrets.yml;
      keys                = [ "password_hash" "test" ];
      userPasswordHashKey = "password_hash"; # must appear in `keys`
    };

    envFile = ./users/env/bas.nix;

    roles = {
      dev.enable     = true;
      ssh.enable     = true;
      secrets.enable = true;

      dotfiles = {
        enable = true;

        # Git-based mode (non-reproducible but simple)
        repo   = "git@github.com:DarkBones/.dotfiles.git";
        dir    = "Developer/dotfiles";
        branch = "nix";
        sparse = [ "nvim" "zsh" ];

        # Shared for both git-mode and pinned-mode:
        linkMap = {
          ".config/nvim" = "nvim/.config/nvim";
          ".zsh"         = "zsh/.zsh";
          ".zshrc"       = "zsh/.zshrc";
        };

        # Optional (future): `sourceKey` for pinned flake input mode
      };
    };
  };
};
```

Meaning:

* `secrets.sopsFile` – which encrypted file to read for this user.
* `secrets.keys` – which top-level YAML keys to expose via `sops-nix`.
* `secrets.userPasswordHashKey` – which of those keys is used as the **login password hash**.

The wiring then looks like this:

* `modules/sops.nix` builds:

  ```nix
  sops.secrets = {
    password_hash = {
      sopsFile = ./users/secrets/bas_secrets.yml;
      format   = "yaml";
      key      = "password_hash";
      owner    = "bas";
      group    = "bas";
      mode     = "0400";
    };
    test = { ... };
  };
  ```

* `modules/users/from-inventory.nix` uses:

  ```nix
  users.users.bas.hashedPasswordFile = config.sops.secrets.${passwordKey}.path;
  ```

where `passwordKey` is `secrets.userPasswordHashKey`.

If you **don’t** want to use sops for a password, you can instead set:

```nix
initialPassword = "changeme";
```

and omit `secrets.userPasswordHashKey`. There are assertions to catch illegal combos, e.g.:

* user sets both sops password and `initialPassword`,
* `userPasswordHashKey` is not in `secrets.keys`.

---

## ⚙️ How sops-nix is hooked up

The sops integration lives in `modules/sops.nix` and, simplified, does:

```nix
imports = [ sops-nix.nixosModules.sops ];

config = lib.mkIf (perUserSecrets != { }) {
  sops = {
    validateSopsFiles = true;

    age = {
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      keyFile     = keyFilePath;   # depends on USB bootstrap
      generateKey = generateKeyFlag;
    };

    secrets = perUserSecrets;      # built from inventory.users.<name>.secrets
  };

  assertions = sopsPasswordKeyAssertions;
};
```

Where:

* `perUserSecrets` is constructed from `inventory.nix`:

  ```nix
  users.bas.secrets = {
    sopsFile            = ./users/secrets/bas_secrets.yml;
    keys                = [ "password_hash" "test" ];
    userPasswordHashKey = "password_hash";
  };
  ```

* For each user, `modules/sops.nix` creates one `sops.secrets.<key>` entry per listed key.

* `modules/users/from-inventory.nix` then consumes those secrets to set:

  * `users.users.<name>.hashedPasswordFile` (if `userPasswordHashKey` is set),
  * or `initialPassword` as a fallback.

---

## 🧩 .sops.yaml structure

`.sops.yaml` tells `sops` *which Age keys* to use for which files.

Example (simplified):

```yaml
keys:
  - &users
    - &bas age1...
  - &hosts
    - &nix_vm age1a...
    - &arch   age1b...
  # You can also add a USB key:
  # - &usb
  #   - &snowman_usb age1c...

creation_rules:
  # Per-user secrets, e.g. users/secrets/bas_secrets.yml
  - path_regex: ^users\/secrets\/.+_secrets\.(yml|yaml)$
    key_groups:
      - age:
          - *bas
          - *nix_vm
          - *arch
          # - *snowman_usb   # optional, if you want USB to decrypt too
```

When you run:

```bash
sops users/secrets/bas_secrets.yml
```

sops will:

* match the `path_regex`,
* encrypt to the listed Age recipients,
* allow decryption on any machine that has one of those private keys.

---

## 💾 USB bootstrap Age key (Snowman key)

When setting up a **brand-new machine or VM**, it might:

* not have its SSH host key registered as an Age recipient yet,
* but you still want it to decrypt your per-user sops secrets.

Snowman supports a **USB bootstrap key**:

* USB is labeled consistently (e.g. `SNOWMANKEY`),
* contains a dedicated Age private key (e.g. `snowman.key`),
* Snowman mounts it and points `sops.age.keyFile` at it during boot.

### 1. Create a dedicated Age keypair

On your main machine:

```bash
# With Nix installed:
nix run nixpkgs#age -- age-keygen -o snowman.key
```

You’ll see something like:

```text
# created: 2025-11-08T20:32:41+01:00
# public key: age1xyz...
```

* Keep `snowman.key` **private**, store it on a USB key.
* Copy the **public key** into `.sops.yaml` (e.g. as `&snowman_usb`).

Example snippet:

```yaml
keys:
  - &usb
    - &snowman_usb age1xyz...

creation_rules:
  - path_regex: ^users\/secrets\/.+_secrets\.(yml|yaml)$
    key_groups:
      - age:
          - *bas
          - *nix_vm
          - *arch
          - *snowman_usb   # now USB can decrypt these secrets too
```

### 2. Prepare your USB drive

1. Format or reuse a small drive.

2. Give the partition the label used in `inventory.nix` (default here: `SNOWMANKEY`), e.g. for FAT32:

   ```bash
   sudo fatlabel /dev/sdX1 SNOWMANKEY
   ```

3. Copy the private key to it:

   ```bash
   sudo mkdir -p /mnt/usb
   sudo mount /dev/sdX1 /mnt/usb
   sudo cp snowman.key /mnt/usb/
   sudo umount /mnt/usb
   ```

Now the USB contains:

```text
/snowman.key
```

### 3. Enable bootstrap for a host

In `inventory.nix`, under your host:

```nix
hosts.vm-snowman = {
  # ...
  bootstrap.usb = {
    enable  = true;
    label   = "SNOWMANKEY";
    path    = "/mnt/snowman";
    keyFile = "snowman.key";
    fsType  = "vfat";
  };
};
```

This:

* defines `/mnt/snowman` in `modules/bootstrap-usb.nix`,
* mounts `/dev/disk/by-label/SNOWMANKEY` there (with `nofail`),
* tells `modules/sops.nix` to use:

  ```nix
  sops.age.keyFile     = "/mnt/snowman/snowman.key";
  sops.age.generateKey = false;
  ```

So sops-nix will **not** generate its own key; it will use the USB’s.

### 4. Bootstrap a new machine

Rough flow:

1. Plug in your Snowman USB (`SNOWMANKEY`) containing `snowman.key`.
2. Boot/install your NixOS host.
3. Ensure your Snowman flake is available on the host (clone / copy).
4. Build + switch (from your dev machine or on-host), e.g.:

   ```bash
   nix run nixpkgs#nixos-rebuild -- switch \
     --flake .#vm-snowman \
     --target-host bas@<target-ip> \
     --build-host bas@<target-ip> \
     --use-remote-sudo
   ```

If the USB + `.sops.yaml` setup is correct, sops-nix will decrypt:

* user secrets from `users/secrets/...`,
* and `modules/users/from-inventory.nix` will see `config.sops.secrets.<key>.path`.

If the USB isn’t present while evaluating on your **dev** machine, that’s fine — it only matters at runtime on the target host.

### 5. After first setup: move away from USB

Once the host is up and stable:

1. Add the **host’s Age key** (derived from SSH host key) to `.sops.yaml`:

   ```bash
   nix run nixpkgs#ssh-to-age -- /etc/ssh/ssh_host_ed25519_key
   ```

2. Add that recipient to the relevant `creation_rules`.

3. Re-encrypt your sops files (open with `sops`, save, commit).

4. In `inventory.nix`, disable USB bootstrap for that host:

   ```nix
   bootstrap.usb.enable = false;
   ```

5. Rebuild; now the host can decrypt using its own keys (SSH host key and/or a local sops key).

---

## 🧱 Quick TL;DR

| Step                                            | Purpose                                        |
| ----------------------------------------------- | ---------------------------------------------- |
| Generate `snowman.key` (Age key)                | Dedicated bootstrap keypair                    |
| Add its public key to `.sops.yaml`              | Let the USB decrypt your sops secrets          |
| Put `snowman.key` on a USB labeled `SNOWMANKEY` | Portable bootstrap device                      |
| Set `bootstrap.usb` in `inventory.nix`          | Mounts USB and points `sops.age.keyFile` there |
| Define `users.<name>.secrets`                   | Wire per-user sops secrets into NixOS          |
| Optionally `userPasswordHashKey` per user       | Use a sops-managed hash as login password      |
| Bootstrap host with USB plugged in              | Secrets decrypt successfully on first setup    |
| Add host’s Age key to `.sops.yaml`              | Let host decrypt without USB                   |
| Disable `bootstrap.usb.enable`                  | Host becomes self-sufficient                   |

---

## 🔍 For maintainers – where things live

* **Host inventory**: `inventory.nix`

  * hardware, filesystem, users, roles, bootstrap USB.
* **Core modules**: `modules/`

  * `hardware/from-inventory.nix` – hostname, bootloader, disko, etc.
  * `users/from-inventory.nix` – user accounts, passwords, assertions.
  * `home/from-inventory.nix` – home-manager per user.
  * `bootstrap-usb.nix` – mounts the USB by label.
  * `sops.nix` – all sops-nix wiring & per-user secret registration.
  * `ssh.nix` – SSH hardening & allowed users.
  * `nix.nix`, `security.nix`, etc. – miscellaneous system config.
* **Home-manager roles**: `modules/home/roles/*.nix`

  * `dev.nix`, `ssh.nix`, `dotfiles.nix`, `secrets.nix` (installs `sops` CLI).
* **Secrets**:

  * `.sops.yaml` – which Age keys protect which files.
  * `users/secrets/*.yml` – actual encrypted secret payloads.

If you keep these pieces in sync, Snowman gives you a **one-command, inventory-driven** NixOS setup with sane secret management, per-user roles, and a clear path for per-host secrets later.
