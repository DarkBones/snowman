# Snowman Config

This repository is your **Snowman body repo**.

This is where you customize your actual machines.

You do **not** need to understand the whole Snowman architecture before you start. The intended path is:

1. change a few obvious values
2. get one machine working
3. learn the deeper features later

## Day One: The Happy Path

Do these first:

1. Open `inventory.nix`.
2. Replace the example host and user values.
3. Keep one simple login method for the first install.
4. Leave optional sections commented out unless you need them now.
5. Install plain NixOS on the target machine.
6. Clone this repo onto that machine.
7. Run `./bin/snowman-import-hardware <host-name>`.
8. Run `sudo nixos-rebuild switch --flake .#<host-name>`.

After your first rebuild, `~/snowman-config/bin` is added to your PATH automatically,
so scripts in your config repo's `bin/` can be run directly.

That is enough for a first successful install.

## First Files To Know

- `inventory.nix`: the main source of truth for hosts, users, roles, and optional secrets/networking wiring
- `flake.nix`: body-repo flake wiring; most new users can leave this alone at first
- `hosts/`: machine-specific NixOS config
- `home/roles/`: reusable Home Manager roles
- `home/overrides/`: one-off Home Manager overrides
- `users/`: user env files, public keys, and encrypted secrets

## What To Change Right Now

In `inventory.nix`, make these changes before your first real install:

- replace the example host name
- replace the example username
- replace `initialPassword = "changeme";` or add SSH keys
- keep `homeManaged = true` for the user you want Home Manager to manage

You can safely ignore for now:

- Wi-Fi declarations
- host secrets
- USB bootstrap keys
- pinned dotfiles inputs
- multi-host role filtering

## Recommended First Install Flow

### 1. Configure one host and one user

Keep it small. One host and one login method is enough.

### 2. Install plain NixOS first

Snowman takes over **after** a normal NixOS install. Do not try to run Snowman from the live ISO.

### 3. Clone this repo onto the installed machine

```bash
nix-shell -p git
git clone <your repo url>
cd <your repo dir>
```

### 4. Import hardware

```bash
./bin/snowman-import-hardware <host-name>
```

This copies the machine's generated hardware config into `hosts/<hostname>-hardware-configuration.nix`.

Note: before first rebuild, use `./bin/...`; after rebuild, scripts in `bin/` are on PATH.

### 5. Rebuild

```bash
sudo nixos-rebuild switch --flake .#<host-name>
```

If that succeeds, your first Snowman machine is live.

## Repo Boundaries

A Snowman setup usually uses three repos:

- **Snowman base**: the framework/engine
- **Body repo**: this repo, where your personal systems live
- **Dotfiles repo**: mutable config content linked into `$HOME`

Use this repo for:

- hosts
- users
- roles
- services
- secrets wiring
- local modules

Use the dotfiles repo for:

- shell config
- editor config
- terminal config
- launcher/bar config
- browser/app config files

## Dotfiles: Learn This After The First Install

Snowman supports a good dotfiles workflow, but you do not need it on day one.

The mental model is:

- **Prod mode**: stable, reproducible, rebuild-oriented
- **Dev mode**: local mutable checkout for fast iteration
- **Git fallback**: fallback when no pinned source is configured

Switching modes changes **where symlinks point**. It does not change the rest of your system structure.

If you want the simplest first install, leave dotfiles as a later step.

## Learn Later

Once one machine works, then learn these in order:

1. custom roles in `home/roles/`
2. dotfiles pinning and `snowman dev` / `snowman prod`
3. SOPS and Age secrets
4. host-local modules and service layout
5. multi-host inventories and role filtering

## AI / Tooling Notes

If an AI assistant is helping you:

- most personal changes belong in this repo, not the Snowman base repo
- dotfile content usually belongs in the dotfiles repo
- framework-wide behavior belongs in Snowman base only if it is generic for all users

For more detailed repo-boundary guidance, see [`AGENTS.md`](./AGENTS.md).
