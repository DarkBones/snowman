# BEFORE RELEASE CHECKLIST

- [ ] Convert all existing encrypted secrets with bogus values

# Snowman – minimal spine

This repo is a **NixOS spine** that:

* builds hosts from a central `inventory.nix`,
* provisions users and their home-manager configs,
* manages secrets via **sops-nix** (per-user),
* optionally bootstraps secrets using a **USB Age key** (“Snowman key”).

It’s meant to be **reproducible**, **host-agnostic**, and **inventory-driven**.

---

## ✅ Before release checklist

* [ ] All **sops secrets use bogus/demo values** (no real API keys or passwords).
* [ ] Each host in `inventory.nix` has:

  * [ ] `mutableUsers = false` if you want full declarative user mgmt.
  * [ ] Correct `hardware.*` and `provision.*` data.
* [ ] `.sops.yaml` includes **only the Age recipients you actually own**.
* [ ] USB bootstrap key is documented & safely backed up.

---

## 🔐 Secrets model (high level)

Snowman uses:

* **[sops](https://github.com/getsops/sops)** for editing encrypted YAML files.
* **[sops-nix](https://github.com/Mic92/sops-nix)** to decrypt them at boot.
* **Age** keys as recipients (some derived from SSH keys, some standalone).

Secrets are:

* stored per-user in `users/secrets/<user>_secrets.yml`,
* encrypted according to rules in `.sops.yaml`,
* made available on the machine via `sops-nix`,
* wired into NixOS via `inventory.nix` (per user).

Example wiring:

* `users/secrets/bas_secrets.yml` (encrypted YAML file)

* `inventory.nix` entry for `users.bas`:

  ```nix
  bas = {
    sopsSecretsFile = ./users/secrets/bas_secrets.yml;
    sopsSecretKeys  = [ "password" "some_api_token" ];
    sopsPasswordKey = "password"; # must appear in sopsSecretKeys
  };
  ```

* `modules/sops.nix` reads that and creates `sops.secrets.<key>` entries.

* `modules/users/from-inventory.nix` consumes those to set e.g. `hashedPasswordFile`.

---

## 🧾 Per-user secrets files

### Where secrets live

For each user that needs secrets, you have:

```text
users/secrets/<name>_secrets.yml   # encrypted with sops
```

Example: `users/secrets/bas_secrets.yml`

The file is a YAML mapping of keys → secret values, e.g.:

```yaml
# users/secrets/bas_secrets.yml (edited via `sops`)
password: "plain-text-password-or-hash"
some_api_token: "sk_1234567890"
github_pat: "ghp_..."
```

> 🔒 Don’t worry: what’s actually committed is an encrypted blob; the above is just the logical shape.

### How it’s wired from inventory

In `inventory.nix`:

```nix
users = {
  bas = {
    uid = 1000;
    homeManaged = true;
    groups = [ "wheel" ];
    shell = "zsh";
    sshPubKeys = [ (builtins.readFile ./users/keys/bas-arch.pub) ];

    sopsSecretsFile = ./users/secrets/bas_secrets.yml;
    sopsSecretKeys  = [ "password" "some_api_token" ];
    sopsPasswordKey = "password"; # used to set the user's password

    roles = {
      dev.enable     = true;
      ssh.enable     = true;
      secrets.enable = true;
      dotfiles = {
        enable = true;
        repo   = "git@github.com:DarkBones/.dotfiles.git";
        dir    = "Developer/dotfiles";
        branch = "main";
        sparse = [ "nvim" ];
        linkMap = { ".config/nvim" = "nvim/.config/nvim"; };
      };
    };
  };
};
```

Meaning:

* `sopsSecretsFile`: which encrypted file to read.
* `sopsSecretKeys`: which top-level keys in that file to expose.
* `sopsPasswordKey`: which key from that list is used as the *user’s password*:

  * `modules/users/from-inventory.nix` does
    `users.users.<name>.hashedPasswordFile = config.sops.secrets.${passwordKey}.path;`
* If you **don’t** want to use sops for a password, you can instead set:

  * `initialPassword = "changeme"` and leave `sopsPasswordKey` unset.

There are assertions to catch mistakes, e.g. if `sopsPasswordKey` is not in `sopsSecretKeys`.

---

## ⚙️ How sops-nix is hooked up

The sops integration lives in `modules/sops.nix` and does roughly:

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
    secrets = perUserSecrets;
  };

  assertions = sopsPasswordKeyAssertions;
};
```

Where:

* `perUserSecrets` is an attrset like:

  ```nix
  {
    password = {
      sopsFile = ./users/secrets/bas_secrets.yml;
      format   = "yaml";
      key      = "password";
      owner    = "bas";
      group    = "bas";
      mode     = "0400";
    };
    some_api_token = { ... };
  }
  ```

* `sops.secrets.<key>.path` is then used by other modules (e.g. for user passwords).

---

## 🧩 .sops.yaml structure

`.sops.yaml` tells `sops` *which Age keys* to use for which files.

Example (simplified):

```yaml
keys:
  - &users:
    - &bas age1...
  - &hosts:
    - &nix-vm age1a...
    - &arch   age1b...
  # you can also add:
  # - &usb
  #   - &snowman_usb age1c...

creation_rules:
  # Per-user secrets, e.g. users/secrets/bas_secrets.yml
  - path_regex: ^users\/secrets\/.+_secrets\.(yml|yaml)$
    key_groups:
      - age:
          - *bas
          - *nix-vm
          - *arch
          # - *snowman_usb   # optional, if you want USB to be able to decrypt

  # Global app-level secrets (if you add them later)
  - path_regex: ^secrets\.(yml|yaml)$
    key_groups:
      - age:
          - *bas
          - *nix-vm
          - *arch
          # - *snowman_usb
```

When you run:

```bash
sops users/secrets/bas_secrets.yml
```

sops will:

* pick the right rule by `path_regex`,
* encrypt to all listed age recipients,
* allow decryption on any machine that has one of those private keys.

---

## 💾 USB bootstrap Age key (Snowman key)

When setting up a **brand-new machine or VM**, it might:

* not have its SSH host key registered as an Age recipient yet,
* but you still want it to decrypt your per-user sops secrets (passwords, tokens, etc).

Snowman supports a **USB bootstrap key**:

* USB is labeled consistently (e.g. `SNOWMANKEY`),
* contains a dedicated Age private key (e.g. `snowman.key`),
* Snowman mounts it and points `sops.age.keyFile` at it during boot.

### 1. Create a dedicated Age keypair

Run this on your main machine:

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
* Copy the **public key** into `.sops.yaml` as another recipient (e.g. `&snowman_usb`).

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
          - *nix-vm
          - *arch
          - *snowman_usb   # now USB can decrypt these secrets too
```

### 2. Prepare your USB drive

1. Format or reuse a small drive.
2. Give the partition the label used in `inventory.nix` (default here: `SNOWMANKEY`):

   ```bash
   sudo fatlabel /dev/sdX1 SNOWMANKEY   # for FAT32
   # or e2label /dev/sdX1 SNOWMANKEY for ext4, etc.
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
vm-snowman = {
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
2. Boot or install your NixOS host.
3. Ensure your Snowman config is in place (clone repo / copy flake).
4. Build + switch (from your dev machine or on-host), e.g.:

   ```bash
   # from your dev machine, using remote build:
   nix run nixpkgs#nixos-rebuild -- switch \
     --flake .#dorkbones \
     --target-host bas@<vm-ip> \
     --build-host bas@<vm-ip> \
     --use-remote-sudo
   ```

If the USB + `.sops.yaml` setup is correct, sops-nix will decrypt:

* user secrets from `users/secrets/...`,
* and `users/from-inventory.nix` will see `config.sops.secrets.<key>.path` normally.

If the USB isn’t present when you evaluate on your **dev** machine, it’s fine — it only matters at runtime on the target host.

### 5. After first setup: move away from USB

Once the host is up and stable:

1. Add the **host’s Age key** (derived from SSH host key) to `.sops.yaml`:

   * On the host:

     ```bash
     # get age recipient for host key (example using ssh-to-age)
     nix run nixpkgs#ssh-to-age -- /etc/ssh/ssh_host_ed25519_key
     ```

   * Add that Age recipient to `.sops.yaml` under `&hosts`.

2. Re-encrypt your sops files (just running `sops` and saving is enough).

3. In `inventory.nix`, disable USB bootstrap for that host:

   ```nix
   bootstrap.usb.enable = false;
   ```

4. Rebuild again; now:

   * `sops.age.generateKey = true` (for a local key), **or**
   * you rely solely on `sshKeyPaths` if that’s enough for your layout.

At that point the host should decrypt secrets using its own keys, no USB needed.

---

## 🧱 Quick TL;DR

| Step                                            | Purpose                                        |
| ----------------------------------------------- | ---------------------------------------------- |
| Generate `snowman.key` (Age key)                | Dedicated bootstrap keypair                    |
| Add its public key to `.sops.yaml`              | Let the USB decrypt your sops secrets          |
| Put `snowman.key` on a USB labeled `SNOWMANKEY` | Portable bootstrap device                      |
| Set `bootstrap.usb` in `inventory.nix`          | Mounts USB and points `sops.age.keyFile` there |
| Define `sopsSecretsFile` / `sopsSecretKeys`     | Wire per-user sops secrets into NixOS          |
| Optionally `sopsPasswordKey` per user           | Use sops-managed secret as the login password  |
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
  * `nix.nix`, `security.nix`, etc – miscellaneous system config.
* **Home-manager roles**: `modules/home/roles/*.nix`

  * `dev.nix`, `ssh.nix`, `dotfiles.nix`, `secrets.nix` (installs `sops` CLI).
* **Secrets**:

  * `.sops.yaml` – which Age keys protect which files.
  * `users/secrets/*.yml` – actual encrypted secret payloads.

If you keep these pieces in sync, Snowman will give you a **one-command, fully-provisioned** system, with secrets handled in a way that’s both ergonomic and reasonably sane.
