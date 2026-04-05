# AGENTS.md

## Purpose

Snowman is an inventory-driven NixOS framework.

This repository is the **Snowman base/engine**. It defines reusable modules, framework contracts, and the template used by new users.

Most users should **not** edit this repo directly. They should create a separate body repo from the template and work there.

## First Decision: Which Repo Owns The Change?

Every Snowman task should be classified before editing anything:

- **Base**: generic framework behavior, template improvements, inventory contracts, reusable modules
- **Body**: personal hosts, users, roles, services, secrets wiring, flake wiring
- **Dotfiles**: shell/editor/browser/terminal/app config files linked into `$HOME`

If the request sounds like "make my machine do X", it almost always belongs in the **body repo**.

If the request sounds like "every Snowman user should be able to do X", it may belong in **base**.

If the request is about config content inside `$HOME`, it usually belongs in **dotfiles**.

When unsure, default to **body repo** and explain why.

## How To Help A New User

Do not teach the whole system at once.

Guide new users in this order:

1. create a body repo from the template
2. replace obvious placeholders
3. get one host and one user working
4. learn roles
5. learn dotfiles modes
6. learn secrets
7. learn multi-host patterns

That staged path is intentional. Do not front-load advanced concepts if they are not needed for the current task.

## Framework Contract

These behaviors are part of the engine and should be preserved unless you are deliberately improving them:

- the base exports `nixosModules.default`, `homeModules.default`, and the template from [`flake.nix`](./flake.nix)
- the body repo's `inventory.nix` is the main source of truth
- every host must define a hostname and at least one user
- every user must provide at least one login method
- Home Manager only applies to users with `homeManaged = true`
- `hosts.<host>.availableRoles` filters enabled user roles on that host
- host, user, and optional network secrets are wired through sops-nix
- prod/dev dotfiles semantics must stay intact

Do not weaken assertions or remove framework contracts unless replacing them with something better and equally explicit.

## Repo Boundaries

### Belongs in Snowman base

- reusable engine behavior
- generic NixOS or Home Manager modules
- inventory schema and assertions
- template improvements for all users
- generic onboarding guidance

### Belongs in the body repo

- host-specific config
- personal users and login methods
- local services and reverse proxy layout
- personal roles and overrides
- machine fleet structure
- personal flake inputs and dotfiles source mapping

### Belongs in the dotfiles repo

- shell config
- editor config
- terminal config
- browser/app config
- themes, wallpapers, and other files linked into `$HOME`

Do not move personal logic into base. Do not move generic framework logic into one user's body repo unless the change is intentionally local.

## Dotfiles Model

Snowman separates dotfiles **content** from dotfiles **wiring**.

Current engine behavior:

- **Pinned source**: dotfiles come from `dotfilesSources` in the body flake
- **Git fallback**: if no pinned source exists, Snowman clones or updates the repo configured in `roles.dotfiles`
- **Prod mode**: stable/reproducible mode
- **Dev mode**: local mutable checkout for fast iteration

The important principle:

> Switching modes changes where symlinks point.

It does not change the overall architecture.

Do not collapse this model into an always-local checkout or an always-impure workflow.

## AI Behavior Rules

When working on Snowman or a Snowman-derived repo:

- preserve the inventory-driven structure
- prefer composable modules over stuffing everything into one host file
- keep generic logic in base and personal logic in body
- keep mutable config content in dotfiles
- explain changes in terms of repo boundaries
- update template/docs when engine behavior changes onboarding or contracts

Do not:

- hardcode personal paths or usernames into base
- suggest editing base for a purely personal change
- remove assertions casually
- break prod/dev dotfiles behavior to paper over a local setup problem

## Common Tasks

### Add a host

Usually **body repo**.

- update `inventory.nix`
- attach host-local modules there
- import hardware config in the body repo

### Add a user

Usually **body repo**.

- define the user in `inventory.nix`
- add login method
- set `homeManaged = true` if Home Manager should apply

### Add a reusable role

Usually **body repo** first.

- add under `home/roles/`
- enable per user
- promote to base only if the role is truly generic

### Add a service or machine-local module

Usually **body repo**.

- keep it host-local unless it is generic across users

### Improve onboarding

Usually **base repo**.

- README
- template files
- comments
- AGENTS/CLAUDE guidance

## Template Warnings

Template values are examples, not production defaults.

Do not assume any of these are final:

- usernames
- hostnames
- repo URLs
- branch names
- placeholder passwords
- example dotfiles settings

An agent should actively replace or call out template placeholders instead of preserving them.

## Editing This Repo

Only edit Snowman base when the change is generic for the framework or for future template users.

When you do:

- keep the change generic
- preserve repo boundaries
- keep the first-run path clear
- update template docs/comments with engine changes

This repo should stay a clean engine, not a personal config.
