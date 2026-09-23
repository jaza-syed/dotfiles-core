# Install

Set up a Mac from nothing in three phases: activate the core's base profile
from an anonymous clone, authenticate with the tools that profile installed,
then switch over to the machine profile. The steps after phase 3 are manual.

## Before starting

1. Sign in to the Mac App Store. The base darwin switch installs App Store
   applications through `mas`, which cannot install them without a sign-in.
2. Have the GitHub and 1Password accounts, including any second factor,
   available.
3. Give the terminal Full Disk Access in System Settings → Privacy & Security.
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

`auth.sh` keeps an existing HTTPS GitHub login. To switch that login to SSH,
run `gh auth login --hostname github.com --web --git-protocol ssh` and complete
its key-registration prompt.

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

gen-m5 replaces phase 3 with the steps in its own install.md, because its
machine repo is on the work GitLab: the clone needs a GitLab sign-in, and the
first switch needs the work secrets.

## After the switch

Check the identity that the machine repo installed:

```sh
git config --get user.name
git config --get user.email
jj config get user.email
```

Create the private SSH config, which the committed SSH config includes:

```sh
touch ~/.ssh/config.local
chmod 600 ~/.ssh/config.local
```

On every Mac, gen-m5 included:

1. In System Settings → Touch ID & Password, add a fingerprint. The darwin
   switch enables Touch ID for sudo, including inside tmux.
2. In System Settings → Privacy & Security, allow:
   - Scroll Reverser under Accessibility and Input Monitoring;
   - AeroSpace and Hammerspoon under Accessibility.
3. In Raycast Settings → Extensions, choose + → Add Script Directory and
   select `~/.config/raycast/scripts`.

On the personal Mac:

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

Every step is rerunnable: rerun `./scripts/auth.sh` for authentication, and
rerun the two switches from the machine repo after pulling changes.
