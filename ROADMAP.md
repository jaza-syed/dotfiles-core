# Roadmap

The goals, in priority order: a clean public core, per-machine configuration
in machine repositories that import the public core, and composition through
the Nix module system. Home Manager and nix-darwin are adopted on upstream
Nix. The public repository holds only the reusable modules. Every machine has
its own repository holding its host composition: `m1` (personal Mac) in
`../dotfiles-m1`, `gen-m5` (work Mac) in `../dotfiles-gen-m5`, and later a
NixOS VPS and a Linux laptop whose OS is still undecided.

Status: the core migration is finished, so items 1–6, 8–11, 13, 14, 16, and the
runbook half of 12 are deleted from this file. The core is modules-only, free
of work config, and public at `github.com/jaza-syed/dotfiles-core`; AGENTS.md
holds the architecture decisions and operations.md holds the commands.
`../dotfiles-gen-m5` imports the core, holds both layers and all work-specific
config, has both layers switched, and is pushed to the work GitLab.
`../dotfiles-m1` exists, is unpushed, and owns the personal Claude settings and
the git/jj identity. Next: the personal Mac bring-up (7) as the first real run
of the reworked bootstrap.

tmux plugins stay on TPM, so plugin management is not on this roadmap.

```
  7  Personal Mac (m1)      NEXT — first run of the reworked bootstrap
        │
 12  Doctor                 drift reporting; the runbook is done
        │
 15  Publish review.nvim    ON HOLD — ownership · author rewrite · license
        │
 17  Nixify linked config   OPEN QUESTION — scopes A–D
        │
  ▼  later hosts            NixOS VPS · Linux laptop (OS open)
```

The common management commands live in [operations.md](operations.md).

## 7. Bring up the personal Mac on its machine repo — not started

- Push `../dotfiles-m1` before the bring-up. It exists and mirrors
  `../dotfiles-gen-m5`: it imports the core and holds
  `homeConfigurations."jsyed@m1"` and `darwinConfigurations.m1`.
- Follow [install.md](install.md): phase 1 activates the core's base profile
  from an anonymous clone, phase 2 authenticates GitHub and 1Password with
  the tools that profile installed, and phase 3 clones `../dotfiles-m1` and
  switches to `.#m1` and `.#jsyed@m1`.
- The phase 1 darwin switch adopts the existing Homebrew prefix through
  nix-homebrew's `autoMigrate`, as it did on gen-m5, where only the
  git-tracked repository files were replaced and the bundle reconciled without
  reinstalling.
- Settle the m1 `services.sketchybar` question, deferred from the move of the
  Homebrew CLIs to Nix: sketchybar comes from nixpkgs and nix-darwin's
  `services.sketchybar` replaces `brew services`. Home Manager's
  `programs.sketchybar.service` is the other candidate, which item 17 covers.
- The manual checklist is unchanged: Mac App Store sign-in, GitHub and
  1Password recovery factors, iCloud, Google Drive plus
  `scripts/link_google_drive.sh`, and notification and accessibility
  permissions.
- Before wiping or retiring any source machine, confirm access to GitHub and
  1Password recovery material and keep a tested fallback until clone, pull,
  push, and SSH authentication work from the laptop.
- Verify Home Manager and nix-darwin activation, generation rollback, shell
  startup, completions, themes, terminfo, and a second activation that
  reports no unexpected changes. Confirm the phase 3 generation cleanly
  replaces the phase 1 base generation. Feed required corrections back into
  `install.md`, the modules, or the machine repo before treating the laptop as
  reproducible.

## 12. Doctor: report drift — not started

The runbook half of this item landed as `operations.md`. The doctor is the
open half:

- Provide a read-only `doctor` command that reports drift between the
  declared state and the mutable surfaces macOS keeps, with exit status by
  severity. Reconciliation stays in `darwin-rebuild switch` and the Homebrew
  cleanup modes; `doctor` only reports.
  - Homebrew drift: the declared bundle in cleanup `check` mode, reporting
    undeclared formulae and casks without removing them.
  - Application bundles in `/Applications` not attributable to a Homebrew
    cask manifest, an App Store receipt via `mas list`, or the documented
    manual-install list.
  - Defaults drift: `defaults read` against declared `system.defaults` keys,
    limited to a chosen subset.
  - Link integrity: broken symlinks in `$HOME` pointing into the repo,
    out-of-store links whose target moved, and a dirty repo tree from apps
    writing back through an out-of-store link.
  - Owner shadowing: for each declared tool, the binary that resolves on
    PATH comes from its declared owner.
  - Nix health: `nix config check`, no leftover nix-channels, and
    generation count and store size as a garbage-collection prompt.
  - mise residue: no `~/.config/mise/config.toml` and no global tool
    versions once mise is project-local only.
  - On a non-NixOS Linux host, if the laptop ends up on Ubuntu: apt drift,
    diffing a declared package list in the repo against
    `apt-mark showmanual`. There is no apt equivalent of the nix-darwin
    Homebrew module, so reporting drift is the whole mechanism.
- Keep README as the short setup entrypoint linked to the runbook, and keep
  implementation contracts in AGENTS.md.

## 15. Publish review.nvim — on hold

`../review.nvim` is a GitLab merge-request review plugin for Neovim, 84
commits, currently pushed to a personal namespace on the work GitLab. The core's
plugin spec in `nvim/.config/nvim/lua/init.lua` points at the local checkout
with `dir = ~/code/jaza-syed/review.nvim` and `enabled` gated on that directory
existing, so the plugin is absent on a fresh machine. Publishing it removes
that gap and makes the core's nvim config work standalone.

Settle first: every commit is authored with the work address and the
remote is the work-associated GitLab namespace, so confirm the plugin is
personal work and that nothing in the employment agreement claims it before
publishing anything.

- Audit the tree and history the way the core was audited before it was
  published: a secret scanner plus a term list. The current tree looks clean of
  employer content; the only work-shaped string is the `allowed_project` guard
  in `tests/live_gitlab.lua`, which names the plugin's own repository and
  follows the repository move. The `mani` dependency is a public tool, so
  it stays.
- Rewrite the author and committer email across all 84 commits to the personal
  address, matching the identity the core now uses.
- Add a LICENSE; the repository has none, so it is currently all-rights-reserved
  and unusable by anyone else.
- Publish to `github.com/jaza-syed/review.nvim` so it sits with the core rather
  than on GitLab, and keep the GitLab remote as a mirror or retire it.
- Switch the core's plugin spec from the local `dir`/`enabled` pair to a plain
  `"jaza-syed/review.nvim"` GitHub spec, add it to `lazy-lock.json`, and drop
  the "optional, enabled when a local checkout exists" wording from README and
  AGENTS.md. The `workspace.mani` argument keeps coming from the machine
  module, so the plugin still no-ops on a machine with no managed workspace.
- Write a README for a reader who is not the author: what it does, the GitLab
  token and `glab` prerequisites, and the mani workspace requirement for the
  inbox.

## 17. Move some out-of-store links into Nix — not started

Almost every config file is an out-of-store link to the checkout
(`nix/home/links.nix`), so the file content is not in the generation: a
rollback does not restore it, CI cannot see it, and a fresh clone has
dangling links until the theme generator runs. The architecture decisions in
AGENTS.md keep actively edited configuration linked out-of-store, and that
decision holds for the files that are edited daily. This item asks which of
the rest are only linked out-of-store by default rather than by choice, and it
revisits that decision for those.

The test for each file, in order:

- Does the app write the file? Then the link must stay out-of-store, or the
  file must be copied rather than linked. Known cases:
  `nvim/.config/nvim/lazy-lock.json` (lazy.nvim writes it back into the
  repo), `~/.claude` and `~/.pi` (the agents write there), and Claude's
  `settings.json`, which is already copied rather than linked because the
  atomic rename replaces a symlink with a regular file.
- Is it edited often enough that a `home-manager switch` per edit is
  annoying? A store file costs one switch per edit.
- Does a machine repo need to change part of it? Nix attribute sets merge
  and plain files do not, which is why the machine surface today is string
  fragments and whole replacement files.

Four scopes, each landable on its own and in rough order of cost.

### A. Verbatim files into the store

Move the rarely edited static files from out-of-store links to store
sources, which is the pattern `nix/home/cli.nix` already uses for the atuin,
direnv, and procs configs. Candidates by size:
`aerospace/.config/aerospace/aerospace.toml` (219 lines),
`hammerspoon/.hammerspoon/init.lua` (135), `vim/.config/vim/vimrc` (75),
`starship/.config/starship.toml` (25), `jj/.config/jj/config.toml` (2). The
content then lives in the generation, so a rollback restores it and a dirty
checkout cannot change the running config. The cost is a switch per edit,
and the aerospace file also has generated `mode-borders-*.sh` siblings that
scope C covers. Where scope B has a module that takes a file or a text block,
prefer that over a bare `xdg.configFile`, since it also brings the module's
package and service handling.

### B. Upstream modules where they exist

The core uses only `programs.git` and `programs.ssh` today, and the pinned
Home Manager (release-26.05) has modules for most of what is linked. Two
kinds, and the distinction decides the cost:

- Modules that take the config verbatim, so the file stays plain text and
  only moves into the store: `programs.sketchybar.config` takes a file path
  or a text block, `programs.wezterm.extraConfig` and
  `programs.tmux.extraConfig` take lua and tmux config as text, and
  `programs.vim` has both `settings` and an `extraConfig` block. For these,
  scopes A and B are the same job.
- Modules that only take an attribute set, so adopting them is a rewrite of
  the file into Nix: `programs.aerospace.settings` (its `extraConfig` option
  was removed and now errors with a pointer to `settings`, so the 219-line
  toml has to be translated), `programs.jujutsu.settings`, and
  `programs.starship.settings`.

Attribute sets give the machine repos real merge semantics, so a machine can
override one key instead of shipping a second whole file.
`programs.starship.settings` would replace `nix/home/starship.nix`, whose
`dotfiles.starship.variant` option exists only because two whole toml files
cannot merge; the module also sets `STARSHIP_CONFIG` from its `configPath`,
and the gen-m5 per-directory prompt switch reads that variable at runtime, so
it needs a second built file either way and would not simplify. The cost of a
rewrite is that the config becomes unreadable to anyone not running this
flake.

The modules also own process management, which is a separate reason to adopt
them: `programs.aerospace.launchd.enable`, `programs.sketchybar.service`, and
`services.jankyborders` each manage a launchd agent, and enabling the
aerospace one forces `start-at-login = false` in the generated config. That
overlaps the m1 sketchybar question in item 7.

Not covered by any module: `hammerspoon` and the Typora themes, so those stay
scope A. Partly covered: the sketchybar module's `config` is only
`sketchybarrc`, and the `items`, `lib`, `plugins`, `render`, and `assets`
directories still need links or store copies. `programs.claude-code` exists
and has `settings`, `agents`, `commands`, `hooks`, `rules`, `skills`,
`outputStyles`, and matching `*Dir` path options. Its `settings` writes
`~/.claude/settings.json` as a store symlink, which Claude's atomic rename
breaks, but that write is guarded on `settings != {}`, so the directory
options can be adopted while leaving `settings` unset and keeping the copy.

### C. Build the generated theme artifacts in the store

`palettes/generate.lua` writes gitignored artifacts into the working tree
and `links.nix` links them out-of-store, so a fresh clone must run
`scripts/generate_colorscheme.sh` before the links resolve. A derivation
running the generator with a nixpkgs luajit would build every variant, and
the links would become store paths. Runtime theme switching still works,
because all variants are built and switching only picks which file to read.
This also removes the manual step in AGENTS.md's "adding a new theme"
procedure: the per-palette links (aerospace `mode-borders-*`, the fzf
themes, the Typora CSS) can be generated from the palette list rather than
listed by hand. The cost is that a palette edit needs a switch before it is
visible, and the generator's edit loop is deliberately switch-free today.

### D. The actively edited trees — out of scope for now

The nvim lua tree, the sketchybar tree, the shell startup files, and the
agent directories are edited many times a day and some are written by their
app. The out-of-store decision should stand for these unless the editing loop
changes.

## Loose ends

- Check the public authentication Gist. The completed bootstrap item said it
  still has to be edited by hand to point at `install.md`, since its URL may
  be linked elsewhere, and the publish item said it was deleted; confirm which
  is true and make AGENTS.md match.
- `networking.hostName` is unset on gen-m5 and could now be managed from
  `../dotfiles-gen-m5`, since there is no MDM on that machine.
