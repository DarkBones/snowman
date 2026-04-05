# Snowman ⛄

Snowman is an **inventory-driven NixOS framework** designed to be a reusable **base** for your own personal, reproducible NixOS configuration.

It is built on a **distro + template** model and a literal **snowman**:

  - **The Snowman Repo (this one):** The **base**. It provides all core modules for users, hardware, secrets, and roles.

  - **Your Config Repo (created from the template):** The **body**. This contains your personal `inventory.nix`, secrets, user definitions, host definitions, dotfiles wiring, etc.

  - **Your Dotfiles Repo (optional, but recommended):** The **head**. This is where your actual editor/shell/tool configs live. Snowman’s roles (e.g. `roles.dotfiles`) mount that “head” onto your Snowman body.

You own your **body repo** forever. Snowman stays the clean, reusable **base** underneath, and your **head** (dotfiles) can evolve independently.

-----

# 🚀 Step 1 — Create Your Personal Config Repo (Snowman Body)

**Do not clone this repo directly.** Instead, generate your *own* repo from Snowman's template.

### Option A: GitHub UI

Click the green **“Use this template”** button on this repo’s GitHub page.

### Option B: From your terminal

```bash
nix flake new -t github:DarkBones/snowman#default my-personal-config
cd my-personal-config
```

This creates your own fresh **Snowman body repo** (configuration directory) powered by the Snowman base.

---

# 🧭 Step 2 — Configure Your System (Inventory First)

Everything you edit happens *inside your personal config/body repo*.
Your new `my-personal-config/` directory is now your “forever config.”

Inside it:

## 1. Edit `inventory.nix`

This is the heart of Snowman.

  * Delete or comment out the example host `vm-snowman`
  * Add your own host (e.g. `my-laptop`)
  * Delete or comment out the example user `bas`
  * Add your own user (e.g. `alice`)

Each host and user lives under:

```nix
hosts = { ... };
users = { ... };
```

**Important:** Each host must set `hosts.<name>.hostname`.

Snowman requires the hostname to be defined explicitly in the inventory.

Example:

```nix
hosts.my-laptop = {
  hostname = "my-laptop";
  # ...
};
```

*(See the "Deep Dive" section below for all available options.)*

## 2. Choose a login method for each user (required)

For **every user listed in `hosts.<host>.users`**, Snowman enforces:

> Each user must provide at least one login method:
>
> * an **SSH key** (`sshPubKeys` / `sshPubKeyFile` / `sshPubKeyFiles`), **or**
> * a **password** (`initialPassword` or sops secrets + `userPasswordHashKey`).

Concretely, in `users.<name>` you can:

### Option A: SSH-only login

```nix
users.alice = {
  uid = 1000;
  groups = [ "wheel" ];
  shell = "zsh";

  # Pick ONE of these styles:
  sshPubKeys = [ "ssh-ed25519 AAAA... alice@laptop" ];
  # or:
  # sshPubKeyFile = ./users/keys/alice.pub;
  # or:
  # sshPubKeyFiles = [ ./users/keys/alice-laptop.pub ./users/keys/alice-desktop.pub ];
};
```

This user passes Snowman’s “login method” assertion (has keys) and can SSH in. They do **not** require a password.

### Option B: Password-only login

```nix
users.alice = {
  uid = 1000;
  groups = [ "wheel" ];
  shell = "zsh";

  # Simple (non-sops) initial password:
  initialPassword = "changeme";
};
```

or with sops-managed password hash:

```nix
users.alice = {
  uid = 1000;
  groups = [ "wheel" ];
  shell = "zsh";

  secrets = {
    sopsFile = ./users/secrets/alice_secrets.yml;
    keys = [ "password_hash" ];
    userPasswordHashKey = "password_hash";
  };
};
```

This user can log in locally via TTY. They **cannot SSH in** by default (SSH is publickey-only; see Deep Dive below).

### Option C: Both SSH + password

You can combine keys and passwords. Snowman only enforces that at least one method exists; having both is fine.

## 3. (Optional) Wire up secrets & extra files

Depending on what you actually need, you can optionally:

* Put your user’s SSH public key(s) into: `users/keys/<name>.pub`
* Create **per-host** secrets: `hosts/secrets/<host>_secrets.yml`
* Create **per-user** secrets: `users/secrets/<name>_secrets.yml`
* Create **network secrets** (for inventory-driven Wi-Fi): `networks/secrets.yml`
* Update `.sops.yaml` with *your* Age public keys.

## 4. Commit your repo

```bash
git add .
git commit -m "Initial Snowman setup"
git push
```

Your **body repo** is now ready to be used on a real machine.

---

# 🏗️ Where to Put Your Configuration

Snowman is layered. Depending on what you are trying to configure, you will edit one of three things:

* The **base** (this Snowman repo) — only if you are developing Snowman itself.
* Your **body repo** (personal config) — where hosts, users, roles, and wiring live.
* Your **head repo** (dotfiles) — where your actual editor/shell/tool configs live.

Within the **body repo**, you usually touch one of three areas:

1. **`inventory.nix` (The Blueprint):** Define hosts, users, secrets, and Wi-Fi.
2. **`hosts/<host-name>.nix` (The System Config):** Machine-specific services, timezones, and NixOS options.
3. **`home/roles/*.nix` (The User Config):** Reusable user environments (Home Manager).

---

# 🖥️ Step 3 — Install NixOS Normally, Then Hand Control to Snowman

Snowman assumes the following "Hand-off" workflow:

> **Install generic NixOS with the normal installer, reboot, log in as your user, then switch the machine over to your Snowman body repo.**

You do **not** run Snowman from the live ISO.

## 1. Install NixOS with the graphical installer

1. Boot the official NixOS ISO.
2. Install normally.

   * **Partitioning:** "Erase Disk" is recommended. If you choose **"Install Alongside"** (Dual Boot), Snowman will work. Snowman does **not** touch your bootloader unless you explicitly opt in via `hosts.<host>.hardware.boot.firmware` (see Deep Dive).
3. **(Recommended)** Ensure `networking.networkmanager.enable = true;` in the generated config so you have Wi-Fi (`nmtui`) after reboot.
4. **Reboot** into your new, generic NixOS installation.

## 2. Clone your Snowman config/body repo on the installed system

```bash
# Get git (if not installed)
nix-shell -p git

# Clone your repo
git clone git@github.com:YourName/my-personal-config.git
cd my-personal-config
```

From now on, **all commands are run inside this body repo**, as that user.

## 3. Import the hardware configuration (CRITICAL)

**Do not skip this step.** Snowman must learn your disk layout (UUIDs) before it builds a working system config.

```bash
./bin/snowman-import-hardware my-laptop
```

This copies the system-generated `/etc/nixos/hardware-configuration.nix` to `hosts/<hostname>-hardware-configuration.nix` (where `<hostname>` is `hosts.<host>.hostname` from your inventory).

## 4. Switch the machine to your Snowman config/body

```bash
sudo nixos-rebuild switch --flake .#my-laptop
```

This **replaces** the installer’s configuration with your Snowman-driven one.

---

# 🛠️ Workflows: Dotfiles (Dev vs. Prod)

Snowman separates two different questions:

1. **Where do the dotfiles come from?**
   - a **pinned source** in your flake inputs (`dotfilesSources`)
   - or a **git checkout** managed on the target machine (`roles.dotfiles.repo`)
2. **How should Home Manager treat them right now?**
   - **PROD**: immutable / rebuild-oriented
   - **DEV**: mutable / edit-in-place

The dotfiles *mode* is resolved once per evaluation and exposed to Home Manager as:

- `config.dotfiles.mode`
- `config.dotfiles.isDev`
- `config.dotfiles.root`

The Snowman **template** ships with a Home Manager override that uses those values to switch between mutable and immutable dotfiles behavior. If you keep the template behavior, the workflows below apply directly.

---

## First: choose a dotfiles source

Snowman supports two source models.

### Option A: Pinned source (recommended)

This is the reproducible setup.

In your body repo `flake.nix`:

```nix
inputs.alice-dotfiles = {
  url = "github:YourName/dotfiles";
  flake = false;
};
```

and then map it:

```nix
dotfilesSources = {
  alice = inputs.alice-dotfiles;
};
```

If `roles.dotfiles.sourceKey` resolves in `dotfilesSources`, Snowman can use that pinned source in PROD mode.

### Option B: Git fallback

If no pinned source is found, Snowman falls back to the git settings in `roles.dotfiles`:

```nix
dotfiles = {
  enable = true;
  repo = "https://github.com/YourName/dotfiles.git";
  dir = "dotfiles";
  branch = "main";
};
```

This is convenient to get started, but it is **not fully reproducible**. Snowman will clone/pull the repo on the target machine during activation.

`roles.dotfiles.dir` accepts three forms:

- relative to the user's home, e.g. `"dotfiles"` or `"Developer/dotfiles"`
- home-relative, e.g. `"~/Developer/dotfiles"`
- absolute, e.g. `"/home/alice/Developer/dotfiles"`

---

## PROD mode

Use:

```bash
snowman prod
```

This performs a **pure** rebuild:

```bash
sudo nixos-rebuild switch --flake .#<host>
```

What PROD means depends on your dotfiles source:

- **Pinned source configured:** the template override points `config.dotfiles.root` at the pinned store path, and Home Manager links from the Nix store. This is the recommended fully reproducible setup.
- **No pinned source configured:** Snowman falls back to the git-based dotfiles role and syncs the checkout in `roles.dotfiles.dir` during activation. This works, but it is not the same as a fully pinned deployment.

Use PROD mode for:

* Daily use
* Machines you want stable
* Deployments where you want the rebuild itself to decide the resulting state

---

## DEV mode

Use:

```bash
snowman dev
```

This performs an **impure** rebuild once to switch modes:

```bash
sudo -E nixos-rebuild switch --impure --flake .#<host>
```

With the template’s Home Manager override, DEV mode means:

* `config.dotfiles.root` points at your local checkout resolved from `roles.dotfiles.dir`
* Home Manager creates **out-of-store symlinks** into that checkout
* After switching once, you can edit dotfiles without rebuilding NixOS again

Typical DEV workflow:

1. Run `snowman dev`
2. Edit files in your local dotfiles repo
3. Restart the affected program (shell, editor, bar, etc.)

Important:

* DEV mode expects the local dotfiles checkout to exist at the path resolved from `roles.dotfiles.dir`.
* DEV mode is mainly for the machine where you actively edit your dotfiles.

---

## Checking the current mode

Dotfiles mode is **global system state**, not shell-local.

Check it with:

```bash
snowman status
```

Example:

```text
dotfiles: DEV (from /etc/snowman/dotfiles-mode)
```

or:

```text
dotfiles: PROD (from /etc/snowman/dotfiles-mode)
```

---

# 🔄 Step 4 — Deploy Updates (From Any Machine)

From your development machine (macOS, Linux, etc.), run:

```bash
nix run nixpkgs#nixos-rebuild -- switch \
  --flake path:/path/to/my-personal-config#my-laptop \
  --target-host alice@my-laptop-ip \
  --use-remote-sudo
```

---

# 📖 Reference & Deep Dive

This section details the advanced configuration available in `inventory.nix`.

## 1. Inventory Structure

### Releases

At the top of `inventory.nix`:

```nix
release = "25.05";
```

Snowman uses this as both the NixOS `system.stateVersion` and the Home Manager `stateVersion`.

### Hosts

Each entry under `hosts` is a machine:

```nix
hosts = {
  my-laptop = {
    hostname = "my-laptop";
    system = "x86_64-linux";
    users  = [ "alice" ];

    # Optional: Advanced hardware/boot control (explicit opt-in)
    hardware.boot.firmware = "efi"; # "bios", "efi", "raspberry-pi", or "none"

    # Optional: Enable compatibility for unpatched binaries (Mason/VSCode)
    compatibility = true;

    # Optional: Limit which roles run on this specific host
    availableRoles = [ "dev" "secrets" ];
  };
};
```

* `compatibility = true`: Enables `nix-ld`, allowing standard Linux binaries (like VSCode Servers or Mason LSPs) to run without patching.
* `availableRoles`: If set, only user roles appearing in this list are applied. This lets you reuse one user definition across many hosts (e.g., enable "gaming" for the user, but filter it out on the work laptop).

#### Boot control

Snowman only configures bootloader behavior if you set `hosts.<host>.hardware.boot.firmware`.

* `"efi"`: enables `systemd-boot` and allows touching EFI variables
* `"bios"`: enables GRUB (device defaults to `/dev/vda` unless `hardware.bootDevice` is set)
* `"raspberry-pi"`: enables generic extlinux
* `"none"`: explicitly disables both GRUB and systemd-boot

If you do **not** set `hardware.boot.firmware`, Snowman will not make bootloader decisions for you.

### Users

A user definition can include roles, which correspond to files in `home/roles/`:

```nix
users.alice.roles = {
  dev.enable = true;
  ssh.enable = true;
  dotfiles = {
    enable = true;
    # ...
  };
};
```

## 2. Wi-Fi Configuration

Snowman allows two modes for networking.

**Mode A: Hand-off (Default)**
If you do not define a `wifi` block, Snowman leaves networking alone. You use `nmtui` or `nmcli` manually.

**Mode B: Declarative (Inventory-Driven)**
Useful for headless machines (Raspberry Pi) or for provisioning NetworkManager profiles.

1. Define networks globally in `inventory.nix`:

   ```nix
   networks = {
     home = { ssid = "my-ssid"; passwordSecret = "home/password"; };
   };
   ```
2. Enable on the host:

   ```nix
   hosts.rpi4.wifi = {
     mode = "static-wifi"; # uses wpa_supplicant + sops (ext:psk_*)
     networks = [ "home" ];
   };
   ```

For interactive laptops, `mode = "roaming"` enables NetworkManager, and (optionally) Snowman can provision profiles if you also set `wifi.networks`.

## 3. SSH Keys vs. Secrets

* **`users/keys/*.pub`**: These are **public** keys used for logging *into* the machine (`authorized_keys`). They are not encrypted.
* **`users/secrets/*.yml`**: These are **private** data (password hashes, tokens) encrypted with **sops**.

## 4. Authentication Matrix

Snowman configures OpenSSH to be **publickey-only** by default.

| SSH keys configured? | Password configured? | SSH login?      | Local TTY login?                     |
| -------------------- | -------------------- | --------------- | ------------------------------------ |
| ✅ Yes                | ❌ No                 | ✅ Yes (key)     | ✅ Yes (if allowed by NixOS defaults) |
| ❌ No                 | ✅ Yes                | ❌ No (key-only) | ✅ Yes                                |
| ✅ Yes                | ✅ Yes                | ✅ Yes (key)     | ✅ Yes                                |

To enable password-based SSH (not recommended), override `services.openssh.settings.PasswordAuthentication = true;` in your `hosts/<name>.nix` file.

---

# 🔐 Secrets Management (Sops & Age)

All secret handling happens **inside your personal config/body repo**.

Snowman uses:

* **sops** to encrypt/decrypt files
* **sops-nix** to expose them to Nix at build time
* **Age keys** as recipients

## Per-user secrets

Example: `users/secrets/alice_secrets.yml`
Mapped in inventory via: `users.alice.secrets.sopsFile`.
Used for password hashes, API tokens, etc.

## Per-host secrets

Example: `hosts/secrets/my-laptop_secrets.yml`
Mapped in inventory via: `hosts.my-laptop.secrets`.
Used for WireGuard keys, host-specific tokens, etc.

## Network secrets (optional, for inventory-driven Wi-Fi)

Example: `networks/secrets.yml`
Used for Wi-Fi PSKs referenced by `inventory.networks.<name>.passwordSecret`.

---

# 💾 Optional: USB Bootstrap Age Key (“Snowman Key”)

This allows a **brand-new machine** to decrypt your secrets *before* it has its own enrolled host key in `.sops.yaml`.

Snowman will only use the USB key if:

* `hosts.<host>.bootstrap.usb.enable = true`, **and**
* the host is **not** already present in `.sops.yaml` (Snowman detects this and treats it as “rotated”)

## 1. Generate a Snowman bootstrap key

```bash
nix run nixpkgs#age -- age-keygen -o snowman.key
```

Put the *public key* into your `.sops.yaml`.

## 2. Prepare the USB

1. Format USB with label `SNOWMANKEY`
2. Copy `snowman.key` (private key) to the root

## 3. Enable in inventory

```nix
bootstrap.usb = {
  enable = true;
  label = "SNOWMANKEY";
  path = "/mnt/snowman";
  keyFile = "snowman.key";
  fsType = "vfat";
};
```

When enabled (and not rotated yet), Snowman mounts the USB and copies the key into `/var/lib/sops-nix/age.key` during activation.

* **Success:** Secrets are decryptable immediately.
* **Missing USB:** The script logs a warning and continues.

## 4. Turn it off after rotation

After installation, once the host is enrolled in `.sops.yaml` (i.e. Snowman considers it “rotated”), USB mode becomes unnecessary.

A typical flow:

1. Convert host SSH key to Age:

   ```bash
   nix run nixpkgs#ssh-to-age -- -i /etc/ssh/ssh_host_ed25519_key.pub
   ```

2. Add the resulting recipient to `.sops.yaml` (using a host anchor like `&<host>`)

3. Re-encrypt secrets:

   ```bash
   sops updatekeys users/secrets/*.yml
   sops updatekeys hosts/secrets/*.yml
   sops updatekeys networks/secrets.yml
   ```

4. Set:

   ```nix
   bootstrap.usb.enable = false;
   ```

From this point on, `sops-nix` will use `generateKey = true` and derive the age identity from the host’s SSH key automatically (no USB required).

---

# 🧑‍💻 For Maintainers (Developing the Snowman Base Itself)

If you are **editing Snowman's modules** (this repo, the **base**) and want to test those changes with your own personal body repo:

## 1. Use two separate repos

* `~/Developer/snowman/` — the **base** (this repo)
* `~/Developer/snowman-config/` — your actual **body** configuration (made from the template)
* `~/Developer/dotfiles/` — your **head** (optional, but nicely thematic)

## 2. Temporarily point your body repo to your local Snowman base

Inside `snowman-config/flake.nix`:

```nix
inputs.snowman.url = "path:../snowman";
```

This allows live testing of base/module changes without pushing to GitHub.

## 3. Deploy from *your body repo* (not from the base)

```bash
cd ~/Developer/snowman-config

nix run nixpkgs#nixos-rebuild -- switch \
  --flake .#my-host \
  --target-host user@host \
  --use-remote-sudo
```

## 4. When satisfied, push updates to GitHub

Then switch your body repo back to the stable GitHub source:

```nix
inputs.snowman.url = "github:DarkBones/snowman";
```

This keeps the Snowman **base** pure and reusable for everyone, while your **body** and **head** stay fully yours.
