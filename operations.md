# Operations

The practical reference for recurring tasks. Setting up a fresh machine is
covered by [install.md](install.md); everything here assumes a machine that is
already set up.

## The daily loop

Editing out-of-store files (nvim, shell startup, sketchybar, the Claude
directory, generated themes) needs no switch, since the links point at the
checkout. A switch is only for package or link changes.

Switches run against the machine repo, one command per layer:

```sh
# User layer
home-manager switch --flake ~/code/jaza-syed/dotfiles-gen-m5#jsyed@gen-m5
home-manager switch --flake ~/code/jaza-syed/dotfiles-m1#jsyed@m1

# System layer
sudo /run/current-system/sw/bin/darwin-rebuild switch --flake ~/code/jaza-syed/dotfiles-gen-m5#gen-m5
sudo /run/current-system/sw/bin/darwin-rebuild switch --flake ~/code/jaza-syed/dotfiles-m1#m1
```

`darwin-rebuild` needs its absolute path because sudo's PATH lacks the nix
directories. The darwin switch must also run from a terminal with Full Disk
Access: the Safari keys in `nix/darwin/defaults.nix` live in a sandboxed
container, and the `defaults` write fails from a terminal without it.

## Getting a core change onto a machine

Push the core, then relock and switch in the machine repo:

```sh
cd ~/code/jaza-syed/dotfiles-gen-m5   # or dotfiles-m1
nix flake update dotfiles
git add flake.lock
git commit -m "relock onto the pushed core"
git push
home-manager switch --flake .#jsyed@gen-m5
```

Renovate also opens weekly lock PRs on the GitHub repos, and a weekly Action
(`nvim-lock-update.yml`) refreshes `nvim-pack-lock.json`, so the machines keep
moving without manual relocks.

To test uncommitted core changes before pushing, override the machine repo's
`dotfiles` input at the local checkout; the machine READMEs carry the exact
command.

## Adding and removing software

- Common CLI tools go in the core's `nix/home/tools.nix`.
- Common casks and App Store apps go in the core's `nix/darwin/homebrew.nix`.
- Machine-specific packages go in the machine repo's `home.nix` or
  `darwin.nix`.

Then switch the affected layer. `homebrew.onActivation.cleanup` is
`"uninstall"`, so a darwin switch removes any formula or cask that is not
declared: an ad hoc `brew install` does not survive the next darwin switch
unless the entry is declared.

Try a tool without declaring it:

```sh
nix shell nixpkgs#<pkg>
```

## Upgrades

`nix flake update` in the core moves its pinned inputs, and Renovate normally
does this through the weekly lock PRs. The machine repos move by relocking,
again normally through Renovate. The release-branch jump (for example
nixos-26.05 to the next release) is manual and follows the work base flake:
edit the branch names in the flake inputs, relock, and switch.

## Rollbacks

```sh
# System layer: the previous darwin generation; no --flake needed
sudo /run/current-system/sw/bin/darwin-rebuild switch --rollback

# User layer: list generations, then run the chosen generation's activate script
home-manager generations
/nix/store/<generation>/activate
```

## Themes

```sh
./scripts/generate_colorscheme.sh
```

The regenerated artifacts flow through the out-of-store links with no switch.
Only a change to the generated file set needs a `nix/home/links.nix` edit and
a home switch; see [AGENTS.md](AGENTS.md).

## Completions

Every home switch regenerates completions through an activation script. By
hand:

```sh
./scripts/generate_completions.sh
exec zsh   # or: exec bash
```

## Garbage collection

```sh
nix-collect-garbage --delete-older-than 30d
```

## Stale shell state after a switch

Running processes keep state from before the switch:

- An existing shell keeps its command hash table, so a moved binary can still
  resolve to its old path. Run `hash -r`.
- The tmux server keeps the environment it started with, and new panes inherit
  it. `tmux kill-server` resets it.
- direnv caches a PATH snapshot per directory until `direnv reload` runs in
  that directory.
