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

# Snowman ⛄

Snowman is an **inventory-driven NixOS framework** designed to be a reusable “engine” for your own personal, reproducible NixOS configuration.

It is built on a **distro + template** model:

* **The Snowman Repo (this one):**
  The *engine*. It provides all core modules for users, hardware, secrets, and roles.

* **Your Config Repo (created from the template):**
  The *car*. This contains your personal `inventory.nix`, secrets, user definitions, host definitions, dotfiles settings, etc.

You own your config repo forever. Snowman stays the clean, reusable engine underneath.

---

# 🚀 Quick Start: Create Your Personal Config Repo

**Do not clone this repo directly for personal use.**
Instead, generate your *own* repo from Snowman's template.

### Option A: GitHub UI

Click the green **“Use this template”** button on this repo’s GitHub page.

### Option B: From your terminal

```bash
nix flake new -t github:DarkBones/snowman#default my-personal-config
cd my-personal-config
```

This creates your own fresh Snowman-powered configuration directory.

---

# 🧭 Step 2 — Configure Your System

Everything you edit happens *inside your personal config repo*.
Your new `my-personal-config/` directory is now your “forever config.”

Inside it:

1. **Edit `inventory.nix`:**
   This is the heart of Snowman.

   * Delete or comment out the example host `vm-snowman`
   * Add your own host (e.g. `my-laptop`)
   * Delete or comment out the example user `bas`
   * Add your own user (e.g. `alice`)

2. **Add your files:**

   * Put your user’s SSH key into:
     `users/keys/<name>.pub`
   * Create `hosts/secrets/<host>_secrets.yml` (encrypted with sops)
   * Create `users/secrets/<name>_secrets.yml` (also sops-encrypted)
   * Update `.sops.yaml` with *your* Age public keys
     (see Secrets section below)

3. **Commit your repo:**

   ```bash
   git add .
   git commit -m "Initial Snowman setup"
   git push
   ```

Your config repo is now ready for installation.

---

# 🖥️ Step 3 — Install a New Machine

1. Boot the target machine using the **official NixOS minimal ISO**.

2. Connect to the internet.

3. Partition and format your disks normally.

4. Mount your root filesystem at `/mnt`, e.g.:

   ```bash
   mount /dev/sda1 /mnt
   ```

5. Install NixOS using your new config repo:

   ```bash
   nix-shell -p git
   nixos-install --flake git@github.com:YourName/my-personal-config#my-laptop
   ```

6. If you enabled the optional USB bootstrap (see below),
   plug in the `SNOWMANKEY` when prompted by sops-nix.

7. Reboot.

Your new Snowman-powered machine will be configured exactly as defined.

---

# 🔄 Step 4 — Deploy Updates

From your development machine (macOS, Linux, etc.), run:

```bash
nix run nixpkgs#nixos-rebuild -- switch \
  --flake path:/path/to/my-personal-config#my-laptop \
  --target-host alice@my-laptop-ip \
  --use-remote-sudo
```

This updates the remote machine using your personal Snowman configuration.

---

# 🔐 Secrets Management (Sops & Age)

All secret handling happens **inside your personal config repo**.

Snowman uses:

* **sops** to encrypt/decrypt files
* **sops-nix** to expose them to Nix at build time
* **Age keys** as recipients

## Per-user secrets

Example path:

```
users/secrets/alice_secrets.yml
```

Example content (encrypted with sops):

```yaml
password_hash: "$y$j9T$..."
github_token: "ghp_123..."
```

Inventory entry:

```nix
users.alice = {
  secrets = {
    sopsFile = ./users/secrets/alice_secrets.yml;
    keys = [ "password_hash" "github_token" ];
    userPasswordHashKey = "password_hash";
  };
};
```

## Per-host secrets

Example path:

```
hosts/secrets/my-laptop_secrets.yml
```

Inventory entry:

```nix
hosts.my-laptop.secrets = {
  sopsFile = ./hosts/secrets/my-laptop_secrets.yml;
  items = {
    wireguard-private-key = {
      key = "wireguard-private-key";
      owner = "root";
      group = "root";
      mode = "0400";
    };
  };
};
```

---

# 💾 Optional: USB Bootstrap Age Key (“Snowman Key”)

This allows a **brand-new machine** to decrypt your secrets *before* it has its own Age key enrolled.

### 1. Generate a Snowman bootstrap key

```bash
nix run nixpkgs#age -- age-keygen -o snowman.key
```

Put the *public key* into your `.sops.yaml` (e.g. under `&snowman_usb`).

### 2. Prepare the USB

1. Format USB with label `SNOWMANKEY`
2. Copy `snowman.key` (private key) to the root

### 3. Enable in inventory

```nix
bootstrap.usb = {
  enable = true;
  label = "SNOWMANKEY";
  path = "/mnt/snowman";
  keyFile = "snowman.key";
  fsType = "vfat";
};
```

### 4. Turn it off after first boot

After installation:

1. Convert host SSH key to Age:

   ```bash
   nix run nixpkgs#ssh-to-age -- /etc/ssh/ssh_host_ed25519_key.pub
   ```
2. Add new Age key to `.sops.yaml`
3. Re-encrypt secrets:
   `sops updatekeys users/secrets/*.yml`
4. Set:

   ```nix
   bootstrap.usb.enable = false;
   ```

Now the machine no longer needs the USB.

---

# 🧑‍💻 For Maintainers (Developing Snowman Itself)

If you are **editing Snowman's modules** and want to test those changes with your own personal config:

### 1. Use two separate repos

* `~/Developer/snowman/` — the engine (this repo)
* `~/Developer/snowman-config/` — your actual configuration (made from the template)

### 2. Temporarily point your config to your local Snowman repo

Inside `snowman-config/flake.nix`:

```nix
inputs.snowman.url = "path:../snowman";
```

This allows live testing of module changes without pushing to GitHub.

### 3. Deploy from *your* config repo (not from Snowman)

```bash
cd ~/Developer/snowman-config

nix run nixpkgs#nixos-rebuild -- switch \
  --flake .#my-host \
  --target-host user@host \
  --use-remote-sudo
```

### 4. When satisfied, push updates to GitHub

Then switch your config back to the stable GitHub source:

```nix
inputs.snowman.url = "github:DarkBones/snowman";
```

This keeps Snowman pure and reusable for everyone.
