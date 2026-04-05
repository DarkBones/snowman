# AGENTS.md

## Purpose

This repository is a **Snowman body repo** created from the template.

It is the user's real config repo. This is usually the correct repo to edit when the task is about:

- hosts
- users
- roles
- services
- secrets wiring
- personal modules
- Home Manager overrides

## Staged Onboarding Rule

Help the user in phases. Do not front-load the entire system.

Recommended teaching order:

1. replace obvious placeholders
2. get one host working
3. learn roles
4. learn dotfiles modes
5. learn secrets
6. learn multi-host patterns

If the current task is a first install, optimize for the shortest safe path to a working machine.

## Three-Repo Model

A Snowman setup usually uses three repos:

### Snowman base

The engine/framework repo.

Owns:

- reusable framework modules
- template files
- inventory contracts and assertions

Users usually do **not** edit Snowman base for personal changes.

### Body repo

This repo.

Owns:

- `inventory.nix`
- host definitions
- user definitions
- local modules
- personal roles and overrides
- personal flake wiring
- secrets references

### Dotfiles repo

A separate repo for mutable config content linked into `$HOME`.

Owns:

- shell config
- editor config
- terminal config
- browser/app config
- themes, wallpapers, and similar files

## First Rule For Agents

Before changing anything, decide:

> Does this belong in base, body, or dotfiles?

Then say which repo owns the change and make it there.

When unsure:

- default to **this body repo**
- unless the task is clearly about framework internals
- or clearly about dotfile content

## What This Repo Owns

This repo usually contains:

- `flake.nix`
- `inventory.nix`
- `.sops.yaml`
- `hosts/`
- `modules/`
- `home/`
- `users/`
- `networks/`

`inventory.nix` is the main source of truth. Prefer changing it first instead of creating parallel definitions elsewhere.

## First-Install Guidance

For a new user, the happy path is:

1. edit `inventory.nix`
2. replace example host/user values
3. keep one simple login method
4. leave optional sections alone for now
5. install plain NixOS
6. clone this repo onto that machine
7. run `./bin/snowman-import-hardware <host-name>`
8. run `sudo nixos-rebuild switch --flake .#<host-name>`

Before first install, verify:

- placeholder usernames and hostnames were replaced
- `changeme` was replaced or intentionally kept only for bootstrap
- the user intended for Home Manager has `homeManaged = true`
- hardware configuration was imported for the target host

## Repo Ownership Rules

### Belongs in this body repo

- adding or changing hosts
- adding or changing users
- enabling roles for a user
- restricting roles with `availableRoles`
- adding local NixOS modules
- wiring local services and reverse proxy layout
- choosing dotfiles source wiring
- adding Home Manager overrides specific to this setup

### Belongs in the dotfiles repo

- Neovim config
- shell config
- tmux config
- terminal emulator config
- browser config files
- Hyprland/Waybar/Wofi/SwayNC config content
- wallpapers and theme assets linked into `$HOME`

### Belongs in Snowman base

Only if it is generic across Snowman users:

- reusable framework features
- new inventory contracts
- template improvements
- engine assertions
- generic onboarding guidance

## Dotfiles Model

This repo usually wires dotfiles but does not own their content.

The mental model is:

- **Prod mode**: stable and reproducible; links point at the pinned/store-backed source when configured
- **Dev mode**: fast iteration; links point at a local checkout
- **Git fallback**: fallback when no pinned source exists

Important principle:

> Switching mode changes where symlinks point.

It does not change the host structure, user structure, or repo boundaries.

If the user is still on their first machine, treat dotfiles as a later topic unless it is blocking the task.

## AI Behavior Rules

When helping in this repo:

- preserve the inventory-driven structure
- keep host-specific logic here, not in Snowman base
- keep mutable config content in dotfiles
- prefer composable modules
- explain whether the change belongs in body, dotfiles, or base

Do not:

- suggest editing Snowman base for a purely personal change
- move mutable config content into this repo unless the user wants that
- remove assertions casually
- bypass inventory structure without a strong reason

## Typical Tasks

### Add a host

Usually this repo.

- add it in `inventory.nix`
- add host-specific modules if needed
- import hardware configuration

### Add a user

Usually this repo.

- add the user in `inventory.nix`
- add login method
- set `homeManaged = true` if Home Manager should apply

### Add a role

Usually this repo first.

- add it under `home/roles/`
- enable it in `inventory.nix`
- restrict it with `availableRoles` if needed

Only move a role to Snowman base if it is genuinely generic.

### Change shell/editor/UI behavior

Usually the dotfiles repo.

Do not reimplement dotfile content in Nix if the setup already treats that content as dotfiles.

## Summary

This repo is where the user's real Snowman setup lives.

Use it to get one machine working first. Then grow into the rest of the system.
