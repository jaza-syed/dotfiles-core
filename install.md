# Install

Set up a Mac from nothing in three phases: activate the core's base profile
from an anonymous clone, authenticate with the tools that profile installed,
then switch over to the machine profile.

Sign in to the Mac App Store first. The base darwin switch installs App Store
applications through `mas`, which cannot install them without a sign-in.

## Phase 1: base profile, public and unauthenticated

```sh
# Nix (upstream installer) — the only curl in the flow; nix-homebrew installs
# Homebrew itself during the darwin switch below
curl -fsSL https://nixos.org/nix/install | sh

mkdir -p ~/code/jaza-syed && cd ~/code/jaza-syed
nix run nixpkgs#git -- clone https://github.com/jaza-syed/dotfiles-core dotfiles
cd dotfiles
sudo nix run nix-darwin/nix-darwin-26.05#darwin-rebuild -- switch --flake .#base
nix run home-manager/release-26.05 -- switch --flake .#base
./scripts/generate_colorscheme.sh   # needs lua from the base profile
```

While this repository is private (until ROADMAP item 9 flips visibility), the
anonymous clone fails. Interim: authenticate first with
`nix run nixpkgs#gh -- auth login --hostname github.com --web --git-protocol ssh`
and clone with `nix run nixpkgs#gh -- repo clone jaza-syed/dotfiles-core dotfiles`.

## Phase 2: authenticate with the installed tools

```sh
open -a 1Password   # sign in, then Settings → Developer → Integrate with 1Password CLI
./scripts/auth.sh   # gh auth login (web, SSH with key registration) + op signin
```

The GitHub sign-in needs the 1Password password and second factor, which is
why 1Password is in the phase 1 base rather than the machine layer.

## Phase 3: switch over to the machine layer

```sh
cd ~/code/jaza-syed
gh repo clone jaza-syed/dotfiles-m1
cd dotfiles-m1
sudo darwin-rebuild switch --flake .#m1
home-manager switch --flake .#jsyed@m1
```

The machine generation replaces the base one, and Home Manager removes the
links it dropped.

gen-m5 keeps an authentication-first order because its machine repo is on the
work GitLab: only the core clone is anonymous there, and phase 3 clones the
machine repo after a GitLab sign-in.

The post-install manual checklist is in [README.md](README.md).
