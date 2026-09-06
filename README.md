# dotfiles

macOS dotfiles managed with Home Manager and nix-darwin. Common configuration
lives in top-level directories that Home Manager links into `~`, exported as
flake modules. Each machine has its own repository (`../dotfiles-m1`,
`../dotfiles-gen-m5`) that imports this core and holds the machine's home and
darwin layers.

## Set up a fresh personal Mac

### Before starting

1. Sign in to the Mac App Store. The bundle contains App Store applications,
   and `mas` cannot install them without an active sign-in.
2. Have the GitHub and 1Password accounts, including any second factor,
   available.

### Install

Follow [install.md](install.md). Phase 1 installs Nix, clones this repo, and
activates the base darwin and home profiles (nix-homebrew installs Homebrew
itself during the switch). Phase 2 signs in to 1Password and GitHub with the
tools the base profile installed. Phase 3 clones the machine repo and switches
to the machine profiles, which apply the machine packages, links, and
identity.

`darwin-rebuild switch` asks for the macOS administrator password.
Authentication preserves an existing HTTPS GitHub login; switching to SSH
requires `gh auth login --hostname github.com --web --git-protocol ssh` and
completing its key-registration prompt.

### Identity and private SSH hosts

Git and jj identity is committed in the machine repo (`programs.git.settings.user`
and the jj `conf.d` fragment in its `home.nix`), so the switch installs it.
The core carries no identity.

Private SSH hosts belong in `~/.ssh/config.local`, which the committed public
SSH config includes:

```sh
touch ~/.ssh/config.local
chmod 600 ~/.ssh/config.local
```

### Verify and rerun

```sh
git config --get user.name
git config --get user.email
jj config get user.email
```

Setup is rerunnable: rerun `./scripts/auth.sh` for authentication, and rerun
the two switches from the machine repo after pulling changes. After a core
push, relock the machine repo with `nix flake update dotfiles`.

### Personal post-install checklist

1. Sign in to iCloud and enable iCloud Drive and Notes.
2. Sign in to the required Google accounts in the browser, Mimestream, and
   Google Drive. After Google Drive has mounted the intended account, create
   the local convenience link:

   ```sh
   cd ~/code/jaza-syed/dotfiles
   ./scripts/link_google_drive.sh
   readlink ~/drive-jaza
   ```

   The helper discovers local accounts and asks which one should back
   `~/drive-jaza` when more than one is mounted. It does not store the account
   name in this repository.
3. Install Ableton Live, Max, Cold Turkey Blocker, and the locally built Noise
   Generator app if needed.
4. In System Settings:
   - disable Siri if desired;
   - select the largest built-in display setting;
   - remap Caps Lock to Control;
   - disable the Control-Space input-source shortcut.
5. Review notification permissions for Mimestream, Calendar, WhatsApp, and
   other communication apps.
6. sketchybar comes from nixpkgs; run it via nix-darwin's
   `services.sketchybar` in the machine repo's `darwin.nix`, or start it
   manually.

A Home Manager activation script clones TPM and plugins declared in
`tmux.conf` when missing, without starting a tmux server. Existing plugin
checkouts are left in place; TPM handles subsequent plugin updates.

The Neovim review integration is optional. It is enabled when a local
`~/code/jaza-syed/review.nvim` checkout exists; a fresh machine starts without
it. Its workspace review commands also require the configured work workspace.

StyLua is installed through Home Manager. From the repository root, format maintained
Neovim Lua files (excluding ignored generated palettes) with:

```sh
rg --files --hidden -0 nvim -g '*.lua' | xargs -0 stylua --config-path .stylua.toml
```

Recurring tasks (switches, updates, rollbacks, garbage collection) are in
[operations.md](operations.md). For repository layout, maintenance workflows,
theme behavior, and Neovim architecture, see [AGENTS.md](AGENTS.md). Future
work is tracked in [ROADMAP.md](ROADMAP.md).
