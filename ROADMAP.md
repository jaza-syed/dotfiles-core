# Roadmap

The goals, in priority order: a clean public core, per-machine configuration
in machine repositories that import the public core, and composition through
the Nix module system. Home Manager and nix-darwin are adopted on upstream
Nix. The public repository holds only the reusable modules. Every machine has
its own repository holding its host composition: `m1` (personal Mac) in
`../dotfiles-m1`, `gen-m5` (work Mac) in `../dotfiles-gen-m5`, and later a
NixOS VPS and a Linux laptop whose OS is still undecided.

Status: items 1–6, 8, 10, 11, and 14 are done. The core is modules-only and
free of work config; the machine repo `../dotfiles-gen-m5` imports the core,
holds both layers and all work-specific config, has both layers
switched (the darwin switch adopted the Homebrew prefix through
nix-homebrew), and is pushed to the work GitLab. The personal machine repo
`../dotfiles-m1` exists (unpushed) and owns the personal Claude settings and
git/jj identity. `scripts/setup-secrets.sh` in the machine repo writes the
work credentials from 1Password. The core restarted its history and is
public at `github.com/jaza-syed/dotfiles-core`, so install.md's anonymous
phase 1 clone works once `main` is pushed. Publishing review.nvim (15) is
next, and the personal Mac bring-up (item 7) is the first real run of the
reworked flow.

tmux plugins stay on TPM, so plugin management is not on this roadmap.

```
 1–6  Core migration          DONE
      1 config dedup · 2 theme generator · 3 nvim lifecycle
      4 decisions · 5 skeleton · 6 ownership migration
        │
 10  Work machine (gen-m5)     DONE — ../dotfiles-gen-m5 imports the core
        │
 11  Finish the work split     DONE — the core is free of work config
        │
 14  Rework the bootstrap      DONE — install.md · base profiles · nix-homebrew
        │
  8  Secrets model             DONE — setup-secrets.sh · 1Password source of truth
        │
  9  Publish the core          DONE — public dotfiles-core · fresh history
        │
 15  Publish review.nvim       NEXT — ownership · author rewrite · license · github spec
        │
  7  Personal Mac (m1)       first run of the reworked bootstrap
        │
 12  Runbook + doctor          operations.md · drift report
        │
 13  CI + updates              eval-only CI · Renovate · tagged releases
        │
  ▼  later hosts               NixOS VPS · Linux laptop (OS open)
```

Common management commands at the end state (exact flags land in
`operations.md`, item 12):

```sh
# Personal Mac: both layers from the machine repo
home-manager switch --flake ~/code/jaza-syed/dotfiles-m1#jsyed@m1
sudo darwin-rebuild switch --flake ~/code/jaza-syed/dotfiles-m1#m1

# Work Mac: both layers from the machine repo
home-manager switch --flake ~/code/jaza-syed/dotfiles-gen-m5#jsyed@gen-m5
sudo darwin-rebuild switch --flake ~/code/jaza-syed/dotfiles-gen-m5#gen-m5

# VPS
nixos-rebuild switch --flake .#<vps-host>

# Non-NixOS Linux (e.g. an Ubuntu laptop): user layer only, like the work Mac;
# apt owns the system layer, and GUI apps come from apt rather than nixpkgs
home-manager switch --flake ~/code/jaza-syed/dotfiles-<host>#jsyed@<host>

# Add/remove software: edit the module or host file, then switch.
# Try something without declaring it
nix shell nixpkgs#<pkg>

# Update pinned inputs, then switch and tag a release for consumers
nix flake update

# Roll back to the previous generation
sudo darwin-rebuild switch --rollback                # system layer
home-manager generations                             # user layer: pick + activate

# Report drift without changing anything (item 12)
doctor

# Regenerate themes (unchanged)
./scripts/generate_colorscheme.sh

# Reclaim disk from old generations
nix-collect-garbage --delete-older-than 30d
```

Editing tracked-but-out-of-store files (nvim, shell startup, Claude, themes)
needs no switch at all; a switch is only for package or link changes.

## 1. Remove small configuration duplication — done

- Remove the settings in the `github.com` SSH block that repeat `Host *`.
- Either manage the `~/.ssh/rc` required by tmux's forwarded-agent socket
  workaround or remove it; nothing in the repo references it today.

## 2. Make the theme generator the only theme catalog — done

- Generate Neovim's background registry from the palette catalog.
- Validate palette schemas and unique background colors once.
- Emit a manifest and prune stale ignored artifacts.
- Remove unused color helpers and move embedded Typora CSS to a normal
  template.
- Add output-equivalence checks before refactoring internals.

## 3. Consolidate Neovim setup and string renderers — done

- Define one setup/reload module registry so startup and reload cannot
  drift.
- Replace duplicated Python, YAML, and Nix multiline-string machinery with
  one configurable parser/extmark/debounce/autocmd engine, retaining
  Nix-specific indentation.
- Consider one `nvim-mini/mini.nvim` repository instead of separate Mini
  repositories and lock entries.
- Add focused behavior checks before highlighter changes.
- The nvim tree stays outside store management throughout, per item 6.

## 4. Record the architecture decisions — done

The design follows
[flakes aren't real and cannot hurt you](https://jade.fyi/blog/flakes-arent-real/):
flakes are an entry point with a pinning system, and everything else uses
the ordinary primitives (functions, overlays, modules). Record these
decisions in AGENTS.md as implementation starts.

- `flake.nix` stays a thin entry point that pins inputs and exports modules
  and host configurations. It contains no logic.
- The public repository holds only the reusable modules (`homeModules.*`,
  `darwinModules.*`, later `nixosModules.*`). Every machine, personal or
  work, has its own repository that imports the core and holds its host
  composition, following the `../dotfiles-gen-m5` pattern. (Revised: the
  personal hosts originally lived in the core; stage 11 retired them. Item 14
  adds back two machine-free base outputs for the bootstrap's first phase.)
- Input overrides and `specialArgs` are not part of the API, since
  `specialArgs` does not compose across flakes. Anything a module needs
  arrives through `pkgs`, options, or lexical closure in the entry point.
- Configuration flows through module options. Use upstream Home Manager and
  nix-darwin options and their merge semantics wherever they exist, for
  example `programs.git.includes`, `programs.ssh.settings`, and
  `homebrew.*`. Define `dotfiles.*` options only where no upstream option
  fits.
- Pins match the work base flake: nixpkgs `nixos-26.05`, Home Manager
  `release-26.05`, and the nix-darwin release branch for the same nixpkgs
  release. Upgrade when the work base flake moves. Tag core releases so
  consumers pin a tag and Renovate bumps it.
- flake-parts and the dendritic pattern are not adopted here. The extra layer
  adds no composition ability this repository uses. Revisit only if the flake
  output layer grows past a screen of per-system boilerplate.
- Modules never fetch at evaluation time. Pinned dependencies enter through
  flake inputs at the entry point only.
- Home Manager feature modules stay platform-neutral where reasonable and
  must work under nix-darwin, NixOS, and standalone Home Manager. The work
  machine uses the standalone mode.
- Actively edited configuration (nvim, shell startup, sketchybar, the Claude
  directory, generated themes) stays as plain files linked out-of-store.
  Moving that content into Nix options is not a goal. Editing a file needs
  no switch, and Home Manager owns only the links and packages.
- Work integration: one machine repository, `../dotfiles-gen-m5` (pushed to
  the work GitLab), imports the core and holds both the `jsyed@gen-m5`
  standalone Home Manager layer and `darwinConfigurations.gen-m5`. It owns
  all work-specific configuration; the core owns ergonomics and stays free
  of work config.

## 5. Build the public core skeleton — done

- Add `flake.nix` with inputs nixpkgs, home-manager, and nix-darwin at the
  pinned releases, and outputs `homeModules`, `darwinModules`, and
  `darwinConfigurations.m1`. Also export one standalone
  `homeConfigurations` target, which is the mode the work machine uses.
  `nixosConfigurations` for the VPS joins later; the Linux laptop adds a
  host once its OS is decided.
- Lay out modules under `nix/`: `nix/home/<feature>.nix`,
  `nix/darwin/<area>.nix`, and `nix/hosts/<host>.nix`, with explicit
  imports rather than directory scanning.
- Enumerate the consumer-facing option surface: Git includes
  (`programs.git.includes`), extra shell env and interactive fragments
  (`dotfiles.shell.*`), extra SSH blocks (`programs.ssh.settings`),
  Homebrew additions (`homebrew.*` merging), `dotfiles.starship.variant`
  for prompt selection, and Neovim local overrides via the nvim tree's own
  `lua/config/local.lua`. Claude settings compose at the Claude layer
  (user, project, and managed settings), not the Nix layer.
- Host files own machine facts: username, home directory, hostname, and
  profile choices. Replace the starter
  `home-manager/.config/home-manager/home.nix`. No module outside
  `nix/hosts/` may hard-code `jsyed` or a home path.
- Public-only evaluation and activation must work with no work-side
  repository present.
- Stow keeps working throughout. The skeleton adds the flake without moving
  any file ownership.

## 6. Migrate ownership into the core — done

Migrate static single-file configs first (git, atuin, procs, direnv, ssh),
larger trees next, and shell startup and nvim last. Each move is: switch,
verify the link and the behavior, then delete the Stow package. Never let
Stow and Home Manager own the same target. `scripts/install.sh` shrinks as
each owner moves; delete its scaffolding (the `--personal` alias, dry-run
branches, and machine resolution) together with the code it guards.

- Move `scripts/macos.sh` to nix-darwin `system.defaults`. Verified
  coverage: `NSGlobalDomain` models every key the script writes except
  `NSAutomaticEmojiSubstitutionEnabled`, and `dock.autohide` and
  `dock.static-only` exist; `CustomUserPreferences` handles remaining
  arbitrary domains, so no residual script should be needed. The Safari
  writes may still fail from activation because Safari preferences live in
  a sandboxed container; the current script has the same constraint, so
  verify on a machine. The script writes `InitialKeyRepeat` as both 4
  (line 15) and 10 (line 86) and the later write wins, so pick one value
  deliberately during the move.
- Replace Brewfile assembly with nix-darwin `homebrew.*` options: the
  common set (today's `Brewfile` and `Brewfile.auth`) becomes a shared
  darwin module, personal casks and Mac App Store entries live in the
  m1 host, and the work set lands in the work darwin host in item 10.
  `taps`, `brews`, `casks`, and `masApps` are all verified present.
  `homebrew.onActivation.cleanup` accepts `none`, `check`, `uninstall`, and
  `zap`; start at `none`, use `check` as the preview, and move to
  `uninstall` once the declared set is verified, replacing `--cleanup`.
  nix-darwin does not install Homebrew itself, so the authentication bootstrap
  keeps that job until item 14 adopts `nix-homebrew`.
- Move dotfiles per tool from Stow packages to Home Manager: `programs.*`
  where an upstream module exists, `home.file`/`xdg.configFile` otherwise.
  Actively edited trees — nvim, sketchybar, generated theme artifacts,
  shell startup files, and the Claude directory — use `mkOutOfStoreSymlink`
  to the repo checkout, per the editing-workflow decision in item 4. Pass
  it an absolute path string, not a Nix path literal, since a path literal
  gets copied into the store during flake evaluation and the link then
  points at the store copy.
- The theme generator keeps writing artifacts into the working tree and Home
  Manager links them out-of-store. Item 2 owns any change to the generator
  itself.
- Prefer completions shipped with Home Manager packages; keep
  `scripts/generate_completions.sh` only for Homebrew-installed tools and
  run it from a Home Manager activation script.
- Install the tmux terminfo entry from an activation script running `tic`,
  replacing the installer step.
- Clone TPM and the tmux plugins declared in `tmux.conf` from a Home
  Manager activation script, replacing `install_tmux_plugins`.
- Remove the repo-wide mise Stow package and `~/.config/mise/config.toml`.
  Home Manager owns the globally wanted tools and toolchains, and mise
  remains for project-local use. Remove `mise install` and `mise prune`
  from the installer.
- Retire `machines/`: `machine.toml`, `DOTFILES_MACHINE`,
  `~/.config/dotfiles/machine`, and `machines/<name>/files` end when host
  files own the facts. Done: `machines/gen-m5` moved to `../dotfiles-gen-m5`
  (item 10) and `machines/m1` to `../dotfiles-m1` (stage 11).
- Script end state: `auth.sh`, `github_auth_bootstrap.sh`,
  `link_google_drive.sh`, and `enable-passwordless-sudo.sh` stay standalone
  scripts; `install.sh` and `macos.sh` are deleted. Done in stage 11.
- Load `brew shellenv` once; today both `zsh/.zprofile` and
  `shell/.config/shell/env.sh` evaluate it, so a login zsh runs it twice.
  Fix it in the shell files when their Stow package migrates.

## 10. Integrate the work machine — done

One thin consumer: the sibling repo `../dotfiles-gen-m5` holds both the
`jsyed@gen-m5` home layer and `darwinConfigurations.gen-m5`, taking the
public core as a flake input. The core input is `git+file` with a local
checkout until item 9 publishes the core, then flips to `github:`. Nix
marks `git+file` inputs as unlocked, so writing the lock needs
`nix flake lock --allow-dirty-locks` and relocking after each core commit
is `nix flake update dotfiles --allow-dirty-locks`. The public repository
never imports or names the machine repo.

Done: the machine repo `../dotfiles-gen-m5` imports the core and holds the
`jsyed@gen-m5` home layer and `darwinConfigurations.gen-m5`; it is pushed to
the work GitLab. The work facts left the public tree (`TICKETS_DIR` via
`dotfiles.shell.extraEnv`, the work starship variant, the work Brewfile
entries, and a private SSH host block), the interim `jsyed@gen-m5` target and
`machines/gen-m5/` are retired, and the darwin system layer is activated
(`InitialKeyRepeat` reads 10).

Remaining:

- There is no MDM on gen-m5. `nix.enable = false` still keeps nix-darwin
  away from the corporate-managed nix install; `networking.hostName` is
  currently unset and could now be managed.
- Secrets stay in uncommitted local files that committed config sources:
  `~/.config/shell/env.local.sh` and `~/.ssh/config.local`. No sops.
- Non-secret machine-specific git and jj config is committed (stage 11):
  the core carries no identity, and each machine repo sets
  `programs.git.settings.user` and a jj `conf.d/machine.toml`. The
  uncommitted `~/.config/git/identity` and
  `~/.config/jj/conf.d/identity.toml` files are unused and can be deleted
  after the next home switch.

## 11. Move the remaining work config out of the core — done

Item 10 moved the machine facts (env, prompt variant, Brewfile, SSH host) to
`../dotfiles-gen-m5`. This stage moved the work-specific behavior that was
still embedded in the public core, so the core evaluates and runs with no
work content. Every injection point below defaults to a no-op when no
machine repo is layered on. This stage also retired the core's host layer
(`nix/hosts/`, `machines/`, `darwinConfigurations.m1`,
`homeConfigurations."jsyed@m1"`, `install.sh`, `macos.sh`, and the common
`Brewfile`), so the core is modules-only and `../dotfiles-m1` owns the
personal host.

Each surface got its own injection mechanism.

Shell. The three interactive entries moved from
`shell/.config/shell/interactive.sh` to the machine repo's
`shell/interactive.sh`, sourced through `dotfiles.shell.extraInteractive`:
the `glab_mr` alias (which pins the work username as assignee), the `mkmr`
function (the `glab mr` scaffold), and the `journal` alias. The `checklist` and `status`
aliases point at the personal `~/drive-jaza` and stay in the core. The
`machine.env.sh` / `machine.interactive.sh` hooks are gone; the
`extraEnv`/`extraInteractive` fragments are the machine surface.

Starship. The work variant toml moved to the machine repo, which links it
into `~/.config/` through its own `xdg.configFile` and keeps its
`dotfiles.starship.variant`. The per-directory switch
(`update_starship_config_for_pwd`) moved whole into the machine fragment,
and the core keeps no path-prefix mechanism.

Neovim (the hard part). The core links `nvim/.config/nvim/lua` as a
whole-directory symlink, so the machine cannot drop a file inside it.
Instead the core prepends `~/.config/nvim-local` to the runtimepath when
that directory exists and resolves the hooks through `config/machine.lua`,
which wraps `pcall(require, "machine")` with no-op defaults. lazy.nvim
resets the runtimepath at setup, so the path is also passed through its
`performance.rtp.paths` option. The machine repo links the module directory
through Home Manager, so it is edited in the machine repo checkout, and no
environment variable is involved, so the behavior is the same however nvim
is launched:

- `config/projects.lua`: kept the generic helpers (`normalize`, `is_under`,
  `workspace_root`, `env_root`); the hard-coded workspace root and its
  predicate are gone, and `direnv_wrap` gates on the machine module's
  is-managed predicate.
- The work policy module moved whole to the machine module (a rust-analyzer
  sysroot and elmls paths for two work sub-repos, and the RooterChDir `lcd`).
- `config/lsp/init.lua`, `config/lint.lua`, `config/dropbar.lua`: gate
  through the hook surface — an is-managed predicate, a `before_init` hook,
  and two dropbar hooks for the project title and path abbreviation; the
  mypy lint policy gates on the same is-managed predicate.
- `init.lua`: the review.nvim spec derives its mani workspace from the
  machine module's `workspace_root` and passes none when it is absent.
- `config/local.lua`: deleted. The colorcolumn setting moved into the
  machine module's `setup`, and the machine module replaces the
  machine-local-override mechanism.
- `tests/nvim_policies.lua`: moved to the machine repo with the policy it
  tests.

Claude. The work-specific Claude config moved out of `claude/.claude/`: the
work and corporate-permissions sections of `CLAUDE.md`, and from
`settings.json` the work-workspace `allow` entries and sandbox
`allowWrite`/`allowRead` paths, the internal-plugin entries, and both
PreToolUse hooks (they only pre-empt the corporate ask rules, which exist
only on the work machine).
The docs confirm the permission lists, hooks, and sandbox path arrays merge
across the settings layers (managed, user, project), but `settings.json` has
no import mechanism, project settings are not read from ancestor directories,
and Claude Code writes to the user file itself (`/model` does), so the user
file must stay a plain writable file. Each machine repo therefore owns
`~/.claude/settings.json` as a checked-in file seeded from the core's base
copy — gen-m5's adds the work entries — and drift is handled by diffing
against the base. For `CLAUDE.md`, the core file imports
`@~/.claude/machine.md` and every machine repo links a fragment there (empty
is fine), which sidesteps the undocumented missing-import behavior.

Kept in the core by decision. The work-oriented but generically named tools
stay in the core: `glab`, `mani`, `kubernetes-cli`, `k9s`, `kubelogin`,
`s3cmd`, `rclone`, `awscli`, `gemini-cli`, `llama.cpp`, `xcodegen`,
`temurin@25`, and the `linear` cask, along with their completion generation.
Of the ambiguous triage only `journal` moves.

Verified: the four machine-repo targets (`jsyed@gen-m5`, `gen-m5`,
`jsyed@m1`, `m1`) pass `nix build --dry-run` against the relocked core; the
moved policies test passes; headless `nvim` loads clean with no machine
module and, with the module linked, reports the workspace root, the
is-managed predicate, the machine autocmds, and the colorcolumn; and the
work term grep (the company name, work usernames and paths, and the private
host IP) finds nothing outside `ROADMAP.md` and `AGENTS.md`, with `glab` kept
in the core as a generic tool. Item 9's publish then scrubbed the remaining
prose references from these two files.

The gen-m5 home layer has since switched onto the machine-repo links, and the
stale identity files are deleted.

## 8. Define durable secrets management and recovery — done

- Define one model for credentials and sensitive material, including SSH
  private keys, signing keys, GitHub/API/cloud tokens, Nix credentials, and
  recovery material. Distinguish secrets from merely private configuration.
- Keep secret values out of every repository and out of the Nix store.
  Store only templates, secret references, and non-secret configuration in
  Git. Secrets stay in uncommitted local files that committed config sources
  (`~/.config/shell/env.local.sh`, `~/.ssh/config.local`); no sops.
  Non-secret git and jj identity config is committed in the machine repos
  (item 10). Personal secrets resolve at runtime through 1Password.
- Work-machine (gen-m5) credentials follow this model concretely, implemented
  as `scripts/setup-secrets.sh` in the machine repo `../dotfiles-gen-m5`:
  - 1Password is the source of truth (`op://Employee/GitLab/token`,
    `op://Employee/Cachix/token`). The script uses the `op` CLI to write
    every credential file, and no 1Password shell plugins are used.
    Some of these files have to exist at rest anyway, because the nix-daemon
    reads them and cannot call `op`. The netrc at `/etc/nix/netrc` needs a
    `machine gitlab.com` line and a `machine` line for the work Cachix cache.
    The gitlab line authenticates both the base-flake `git+https` fetch and the
    private PyPI index, which is also served from `gitlab.com`
    (`/api/v4/groups/<id>/-/packages/pypi/simple`); netrc keys on host, so one
    line covers both, and the PAT needs `api` scope as well as
    `read_repository`. The path is fixed at `/etc/nix/netrc` because the base
    flake's pyproject overlay patches curl with `--netrc-file /etc/nix/netrc`.
    Rerun the script when the GitLab PAT rotates.
  - `glab` reads its token from `~/.config/glab-cli/config.yml`, which the
    script writes by piping `op read` into
    `glab auth login --hostname gitlab.com --stdin`. The same GitLab PAT as
    the netrc line, so one rotation updates both.
  - Cachix needs two files, both written by the script: the daemon pull
    authenticates through the netrc work-cache line (above), and
    the `cachix` CLI reads its token from `~/.config/cachix/cachix.dhall`
    (what `cachix authtoken` writes). The gen-m5 home layer installs `cachix`,
    so switch the home layer before the first script run.
  - Tools that read a token from the environment get one from
    `~/.config/shell/secrets.env.sh`, which the script generates and the
    committed gen-m5 `extraEnv` sources when present. It exports
    `GITLAB_TOKEN` (the same PAT as the netrc and `glab` lines) and
    `GITHUB_TOKEN` (captured from `gh auth token`). `gh` is the exception:
    `scripts/auth.sh` unsets `GITHUB_TOKEN` around `gh auth`, since an
    environment token overrides the keyring login it manages. Non-secret
    variables are committed directly: the gen-m5 `extraEnv` exports
    `GITLAB_USER`.
- Use separate passphrase-protected, per-machine SSH keys for personal and
  work access. Keep private keys local, use the macOS Keychain-backed agent,
  and register and revoke each device independently. Do not sync SSH private
  keys through 1Password.
- Preserve the public GitHub authentication bootstrap as the recoverable
  seed path for private-repository cloning. Keep 1Password responsible for
  account credentials and second factors, not SSH private-key storage.
- Use [1Password CLI secret references](https://www.1password.dev/cli/secrets-scripts)
  with `op read` and `op inject` in the setup script, and `op run` where a
  command can take its credential at launch. Only the references live in Git;
  the resolved files are local and uncommitted.
- No further SSH-key or recovery work is planned (decided): the existing
  per-machine SSH keys and the GitHub/1Password recovery factors stay as they
  are, and the unlock/fail-closed rules and the rotation and recovery runbook
  are not being written.

## 9. Publish the public core — done

- Instead of rewriting history, the core restarted it. The tree was audited
  (gitleaks plus the term list: no secrets; company references remain only as
  prose in `ROADMAP.md` and `AGENTS.md`), then `main` was collapsed to a
  single fresh commit authored with the personal identity, and `origin` now
  points at the new public `github.com/jaza-syed/dotfiles-core`. The old
  history survives only in the old private `github.com/jaza-syed/dotfiles`;
  the local backup branch was deleted so it cannot be pushed by accident.
- The authentication Gist is deleted; `install.md` is the only bootstrap
  document.
- Keep the public repository useful on its own as the personal/common base.
- Make setup a one-command, idempotent, testable path with and without the
  work-side repositories.

## 15. Publish review.nvim — not started

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

- Audit the tree and history the same way as item 9: a secret scanner plus a
  term list. The current tree looks clean of employer content; the only
  work-shaped string is the `allowed_project` guard in
  `tests/live_gitlab.lua`, which names the plugin's own repository and
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

## 14. Rework the bootstrap into base-then-machine phases — done

Implemented. The anonymous phase 1 clone starts working when item 9 flips
visibility; until then `install.md` carries interim authenticated-clone
commands using `nix run nixpkgs#gh`.

The Gist existed to solve one problem: both repositories are private, so
a wiped machine must seed GitHub and 1Password authentication before it can
clone anything. Item 9 publishes the core, but the machine repo stays private.
`../dotfiles-m1` holds the git and jj identity email, the personal cask and
App Store list, and after item 11 `claude/settings.json` and
`claude/machine.md`. Authentication is therefore still required, and it moves
from before the first clone to between the two clones.

The shape is base first, then machine: activate the core's base profile from
an anonymous clone, authenticate with the tools that profile installed, clone
the machine repo, then switch over to the machine profile.

Phase 1, public and unauthenticated:

```sh
# Nix (upstream installer) — the only curl in the flow, since nix-homebrew
# installs Homebrew during the darwin switch below
curl -fsSL https://nixos.org/nix/install | sh

mkdir -p ~/code/jaza-syed && cd ~/code/jaza-syed
nix run nixpkgs#git -- clone https://github.com/jaza-syed/dotfiles
cd dotfiles
sudo nix run nix-darwin/nix-darwin-26.05#darwin-rebuild -- switch --flake .#base
nix run home-manager/release-26.05 -- switch --flake .#base
./scripts/generate_colorscheme.sh   # needs luajit or lua from the home profile
```

Phase 2, authenticate with the installed tools:

```sh
open -a 1Password   # sign in, then Settings → Developer → Integrate with 1Password CLI
gh auth login --hostname github.com --web --git-protocol ssh
./scripts/auth.sh
```

Phase 3, switch over to the machine layer:

```sh
cd ~/code/jaza-syed
gh repo clone jaza-syed/dotfiles-m1
cd dotfiles-m1
sudo darwin-rebuild switch --flake .#m1
home-manager switch --flake .#jsyed@m1
```

What the core provides:

- Base host outputs, `darwinConfigurations.base` and `homeConfigurations.base`,
  carrying no machine facts beyond the username and home directory. Stage 11
  left the core modules-only, so these two came back as its only host outputs.
  They also give item 9's "useful on its own" goal and item 5's public-only
  activation requirement a concrete target to test.
- Home Manager requires `home.username` and `home.homeDirectory`, and the
  darwin layer requires `system.primaryUser` and `users.users.<name>.home`.
  Hard-code `jsyed` in the base outputs rather than adding `--impure` and
  `builtins.getEnv`, since the core is the personal base and the name is in
  its commit history regardless.
- Phase 1 must include the darwin switch, because `gh`, `1password`, and
  `1password-cli` are Homebrew entries in `nix/darwin/homebrew.nix` and phase 2
  needs them. Moving `gh` and `_1password-cli` to the home layer as nixpkgs
  packages would make phase 1 home-only, which repackages working tools for no
  gain here.
- `Brewfile.auth` and `scripts/github_auth_bootstrap.sh` retired, since phase
  1 installs what they installed, and `scripts/bootstrap.sh` went with them
  since it existed to chain them. `scripts/auth.sh` stays as a phase 2 step.

Adopted `nix-homebrew`. It installs Homebrew itself during the darwin
activation, which item 6 left to the bootstrap, so Nix is the only installer
the flow curls. The flake input belongs to the core (nix-homebrew has no
nixpkgs input of its own), and `darwinModules.homebrew` imports
`nix-homebrew.darwinModules.nix-homebrew` through lexical closure with
`enable` and `autoMigrate` set, so no machine repo adds an input;
`nix-homebrew.user` is a machine fact that each host file sets. The two
checks came back clean: the module prepends its prefix setup to nix-darwin's
own homebrew activation and satisfies the preflight check, so a single
`darwin-rebuild switch` installs Homebrew and then reconciles the declared
bundle; and taps stay mutable by default, in which case brew fetches from the
API and no tap is pinned as a flake input, while `mutableTaps = false` would
break `brew tap`, `brew update`, and the cleanup mode's untap.

The Gist became a markdown file: `install.md` in the core, one shell section
per phase, linked from README, with no `?v=N` pin since nothing curls it.
Still to do by hand: edit the public Gist to point at `install.md`, since its
URL may be linked elsewhere.

Caveats:

- Mac App Store sign-in still comes first, because phase 1's darwin switch
  installs `masApps`.
- The phase 2 GitHub sign-in needs the 1Password password and second factor,
  which is why 1Password belongs in the phase 1 base rather than the machine
  layer.
- `nix run nixpkgs#git` avoids depending on the Xcode Command Line Tools
  prompt for git. I think a plain `git clone` would also work once macOS
  offers to install the tools, and the nix form removes that interruption; a
  fresh-machine test would confirm it.
- Phase 3 leaves a second darwin and home generation. The machine generation
  replaces the base one and Home Manager removes the links it dropped; verify
  that during the item 7 bring-up.
- `gen-m5` keeps an authentication-first bootstrap, since its machine repo is
  on the work GitLab. Only the core clone is anonymous there.
- gen-m5 has run its first darwin switch with nix-homebrew: `autoMigrate`
  adopted the curl-installed prefix (only the git-tracked repository files
  were replaced, keeping the Cellar and Caskroom) and the bundle reconciled
  all 104 dependencies without reinstalling. m1 adopts its prefix the same
  way at the item 7 bring-up.

## 7. Bring up the personal Mac on its machine repo — not started

Moved after item 14 so the bring-up is the first real run of the reworked
bootstrap, rather than exercising a flow that item 14 then replaces. That also
means the three phases get tested on the machine they were written for.

- Push `../dotfiles-m1` before the bring-up. It exists and mirrors
  `../dotfiles-gen-m5`: it imports the core and holds
  `homeConfigurations."jsyed@m1"` and `darwinConfigurations.m1`.
- Follow item 14's `install.md`: phase 1 activates the core's base profile
  from an anonymous clone, phase 2 authenticates GitHub and 1Password with
  the tools that profile installed, and phase 3 clones `../dotfiles-m1` and
  switches to `.#m1` and `.#jsyed@m1`.
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
  replaces the phase 1 base generation, per item 14's caveat. Feed required
  corrections back into `install.md`, the modules, or the machine repo before
  treating the laptop as reproducible.

## 12. Write the operations runbook — not started

- Write `operations.md` as the practical reference for recurring tasks:
  bootstrapping, adding and removing packages, temporary package trials,
  upgrades, cleanup preview and apply, rollbacks, theme regeneration, and
  adding a host.
- The lifecycle is nix-darwin and Home Manager generations plus
  `homebrew.onActivation` cleanup. Document evaluation, build, switch,
  generation rollback, and garbage collection for each layer.
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

## 13. Add CI and automate updates — not started

- CI is evaluation-only (decided): evaluate the host closures and a sample
  home against the pinned Home Manager release on Linux runners, plus shell
  syntax checks, StyLua, and the policy tests under `tests/`. Building the
  darwin closure needs macOS runners; add such a job only if evaluation
  misses real breakage.
- Automate `flake.lock` updates (nixpkgs, home-manager, nix-darwin), GitHub
  Actions pins, and the Neovim plugin lock with Renovate. Renovate's nix
  manager updates all flake inputs but is beta and off by default, so set
  `"nix": { "enabled": true }`; Dependabot has no Nix support. Group
  updates on a low-noise schedule, handle security updates separately, and
  auto-merge only what CI covers.
- Tag a core release after lock bumps that consumers should pick up; the
  work-side Renovate bumps the tag.
- Work-side dependencies and their updater configuration live in the
  work repositories.
