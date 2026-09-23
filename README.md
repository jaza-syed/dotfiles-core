# dotfiles

macOS dotfiles managed with Home Manager and nix-darwin. Common configuration
lives in top-level directories that Home Manager links into `~`, exported as
flake modules. Each machine has its own repository (`../dotfiles-m1`,
`../dotfiles-gen-m5`) that imports this core and holds the machine's home and
darwin layers.

## Setting up a Mac

[install.md](install.md) contains every step. Phase 1 installs Nix, clones
this repo, and activates the base darwin and home profiles, and nix-homebrew
installs Homebrew itself during that switch. Phase 2 signs in to 1Password and
GitHub with the tools the base profile installed. Phase 3 clones the machine
repo and switches to the machine profiles, which apply the machine packages,
links, and identity. The manual steps after that are account sign-ins and
macOS permissions.

## Identity and private SSH hosts

Git and jj identity is committed in the machine repo (`programs.git.settings.user`
and the jj `conf.d` fragment in its `home.nix`), so the switch installs it.
The core carries no identity.

Private SSH hosts belong in `~/.ssh/config.local`, which the committed public
SSH config includes.

## Behaviour on a fresh machine

A Home Manager activation script clones TPM and plugins declared in
`tmux.conf` when missing, without starting a tmux server. Existing plugin
checkouts are left in place, and TPM handles subsequent plugin updates.

The Neovim review integration is optional. It is enabled when a local
`~/code/jaza-syed/review.nvim` checkout exists, so a fresh machine starts
without it. Its workspace review commands also require the configured work
workspace.

sketchybar comes from nixpkgs. gen-m5's `darwin.nix` runs it through
nix-darwin's `services.sketchybar`.

Recurring tasks (switches, updates, rollbacks, garbage collection, formatting)
are in [operations.md](operations.md). For repository layout, maintenance
workflows, theme behavior, and Neovim architecture, see [AGENTS.md](AGENTS.md).
Future work is tracked in [ROADMAP.md](ROADMAP.md).
