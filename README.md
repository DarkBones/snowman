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

Snowman is an inventory-driven NixOS framework designed to be a reusable "engine" for your own personal NixOS configuration.

It is built on a "distro" and "template" model:

  * **The Snowman Repo (this one):** The "engine." It provides all the core `modules/` for handling users, hardware, and secrets.
  * **Your Config Repo (yours):** The "car." You create this from the `template/` in this repo. It's where your personal `inventory.nix`, secret files, and host definitions live.

## 🚀 Quick Start: The New User Workflow

This is the official workflow for a new user starting a "Snowman-powered" configuration.

### 1. Create Your Personal Config Repo

**Do not clone this repo.** Instead, use it as a template to create your *own* new, private repository.

You can click the green **"Use this template"** button on this repo's GitHub page.

Or, from your terminal:

```bash
nix flake new -t github:DarkBones/snowman my-personal-config
cd my-personal-config
```

### 2. Configure Your System

Your new `my-personal-config` directory is now your "forever" config. All your edits happen here.

1.  **Edit `inventory.nix`:** This is your main file.
      * Delete or comment out the example `vm-snowman` host.
      * Add your new host (e.g., `my-laptop`).
      * Delete or comment out the example `bas` user.
      * Add your new user (e.g., `alice`).
2.  **Add Your Files:**
      * Add your user's SSH public key to `users/keys/`.
      * Create `hosts/secrets/my-laptop_secrets.yml` and `users/secrets/alice_secrets.yml` using `sops`.
      * Update `.sops.yaml` with *your* Age public keys. (See the "Secrets Management" section below).
3.  **Commit:** `git add .`, `git commit -m "Initial config for my-laptop"`, and `git push` to your new repo.

### 3. Install a New Machine

1.  Boot the target machine from the **official NixOS minimal ISO**.

2.  Connect to the internet and partition your drives.

3.  Mount your new root filesystem to `/mnt`. (e.g., `mount /dev/sda1 /mnt`).

4.  Run `nixos-install`, pointing it at *your* new repo and host:

    ```bash
    # (Inside the ISO environment)
    nix-shell -p git
    nixos-install --flake git@github.com:YourName/my-personal-config#my-laptop
    ```

5.  If you're using the USB key method, `sops-nix` will pause and wait. Plug in your `SNOWMANKEY` USB to continue.

6.  `reboot` when finished.

### 4. Deploy Updates

To push updates to your machine *after* it's been installed, run this from your main (Arch/Mac) development machine:

```bash
# Deploys the 'my-laptop' config from your flake
nix run nixpkgs#nixos-rebuild -- switch \
  --flake path:/path/to/my-personal-config#my-laptop \
  --target-host alice@my-laptop-ip \
  --use-remote-sudo
```

-----

## 🔐 Secrets Management (Sops)

All file paths below are relative to **your personal config repo** (the one you made from the template).

### Secrets model (high level)

Snowman uses:

  * **[sops](https://github.com/getsops/sops)** for editing encrypted YAML files.
  * **[sops-nix](https://github.com/Mic92/sops-nix)** to decrypt them at boot.
  * **Age** keys as recipients.

Secrets are:

  * Stored per-user (e.g., `users/secrets/<user>_secrets.yml`) and per-host (e.g., `hosts/secrets/<host>_secrets.yml`).
  * Encrypted according to rules in `.sops.yaml`.
  * Wired into NixOS via the `secrets` attribute in `inventory.nix`.

### Per-user secrets files

For each user, you have:
`users/secrets/<name>_secrets.yml` \# encrypted with sops

Example: `users/secrets/bas_secrets.yml`

```yaml
# users/secrets/bas_secrets.yml (edited via `sops`)
password_hash: "$y$j9T$..."
test: "some-random-test-secret"
```

### How it’s wired from inventory

In `inventory.nix`, the **user** has a nested `secrets` block:

```nix
users = {
  bas = {
    # ...
    secrets = {
      sopsFile = ./users/secrets/bas_secrets.yml;
      keys = [ "password_hash" "test" ];
      userPasswordHashKey = "password_hash"; # must appear in `keys`
    };
    # ...
  };
};
```

  * `secrets.sopsFile`: Which encrypted file to read.
  * `secrets.keys`: Which top-level YAML keys to expose via `sops-nix`.
  * `secrets.userPasswordHashKey`: Which of those keys is the **login password hash**.

If you don't want a Sops-managed password, set `initialPassword = "changeme";` instead and omit the `secrets` block.

-----

## 💾 USB Bootstrap Age key (Snowman key)

For a brand-new machine, this lets it decrypt secrets before it has its own registered SSH key.

### 1. Create a dedicated Age keypair

On your main machine:

```bash
nix run nixpkgs#age -- age-keygen -o snowman.key
```

  * You get `snowman.key` (private) and a public key `age1...`.
  * Copy the **public key** into your `.sops.yaml` (e.g., as `&snowman_usb`).
  * Run `sops updatekeys users/secrets/your_file.yml` to apply the new key.

### 2. Prepare your USB drive

1.  Format a drive with the label `SNOWMANKEY`.
2.  Copy the **private key** `snowman.key` to the root of the drive.

### 3. Enable bootstrap for a host

In your `inventory.nix`, under your host:

```nix
hosts.my-laptop = {
  # ...
  bootstrap.usb = {
    enable = true;
    label = "SNOWMANKEY";
    path = "/mnt/snowman";
    keyFile = "snowman.key";
    fsType = "vfat";
  };
};
```

The Snowman modules will automatically mount this drive and use the key to unlock your Sops secrets at boot.

### 4. After first setup: move away from USB

Once the host is up:

1.  Get the host's new Age key: `nix run nixpkgs#ssh-to-age -- /etc/ssh/ssh_host_ed25519_key.pub`
2.  Add that new public key to your `.sops.yaml`.
3.  Run `sops updatekeys ...` on your secret files.
4.  In `inventory.nix`, set `bootstrap.usb.enable = false;` for that host.
5.  Re-deploy. The host is now self-sufficient and no longer needs the USB.

-----

## 🧑‍💻 For Maintainers (Developing Snowman)

If you are "dogfooding" (editing the Snowman framework and testing it with your personal config), your workflow is slightly different.

Your setup:

  * **`~/Developer/snowman/`** (This repo)
  * **`~/Developer/snowman/flake.nix`** (The "distro" flake)
  * **`~/Developer/snowman/template/`** (Your personal config)

To test your local changes to the `modules/`:

1.  **Edit `template/flake.nix`:**
    Make sure the `snowman` input points to your local files, not GitHub.

    ```nix
    inputs.snowman = {
      url = "path:.."; # This is the important line
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ```

2.  **Deploy from the root:**
    Run your deploy commands from the *root* of the `snowman` repo, but point the flake flag at the `template/` directory.

    ```bash
    # This builds the 'vm-snowman' host defined in 'template/inventory.nix'
    # using the 'snowman' modules from the parent directory.
    nix run nixpkgs#nixos-rebuild -- switch \
      --flake ./template#vm-snowman \
      --target-host bas@192.168.122.241 \
      --use-remote-sudo
    ```
