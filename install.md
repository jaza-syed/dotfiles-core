# Install

Set up a Mac from nothing in three phases: activate the core's base profile
from an anonymous clone, authenticate with the tools that profile installed,
then switch over to the machine profile.

Before starting:

- Sign in to the Mac App Store. The base darwin switch installs App Store
  applications through `mas`, which cannot install them without a sign-in.
- Give the terminal Full Disk Access in System Settings → Privacy & Security.
  The darwin switch writes Safari defaults, and that write fails without it.

## Phase 1: base profile, public and unauthenticated

Each block ends with `exec zsh` where the next block needs a new `PATH`.

```sh
# Nix (upstream installer) — the only curl in the flow; nix-homebrew installs
# Homebrew itself during the darwin switch below
curl -fsSL https://nixos.org/nix/install | sh
exec zsh   # puts nix on PATH
```

Until the base darwin switch writes `nix.conf`, flakes are off, so the first
commands pass the experimental features on the command line. There is one
base output per username, `base-jsyed` and `base-generative`.

```sh
mkdir -p ~/code/jaza-syed && cd ~/code/jaza-syed
nix --extra-experimental-features nix-command --extra-experimental-features flakes \
  run nixpkgs#git -- clone https://github.com/jaza-syed/dotfiles-core dotfiles
cd dotfiles
sudo nix --extra-experimental-features nix-command --extra-experimental-features flakes \
  run nix-darwin/nix-darwin-26.05#darwin-rebuild -- switch --flake .#base-$(id -un)
nix --extra-experimental-features nix-command --extra-experimental-features flakes \
  run home-manager/release-26.05 -- switch --flake .#base-$(id -un)
exec zsh   # puts the base profile on PATH
```

```sh
./scripts/generate_colorscheme.sh   # needs lua from the base profile
```

## Phase 2: authenticate with the installed tools

```sh
open -a 1Password   # sign in, then Settings → Developer → Integrate with 1Password CLI
./scripts/auth.sh   # gh auth login (web, SSH with key registration) + op signin
```

The GitHub sign-in needs the 1Password password and second factor, which is
why 1Password is in the phase 1 base rather than the machine layer.

Passwordless sudo is a manual choice for each machine. The script installs a
`NOPASSWD` rule for the current user in `/etc/sudoers.d` and validates it with
`visudo`:

```sh
./scripts/enable-passwordless-sudo.sh
```

## Phase 3: switch over to the machine layer

```sh
cd ~/code/jaza-syed
gh repo clone jaza-syed/dotfiles-m1
cd dotfiles-m1
sudo /run/current-system/sw/bin/darwin-rebuild switch --flake .#m1
home-manager switch --flake .#jsyed@m1
```

The machine generation replaces the base one, and Home Manager removes the
links it dropped.

gen-m5 replaces phase 3 with the set-up steps in its own README, because its
machine repo is on the work GitLab: the clone needs a GitLab sign-in, and the
first switch needs the work secrets.

The post-install manual checklist is in [README.md](README.md).
