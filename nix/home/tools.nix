# Base package set: what the linked config needs plus the daily CLI. Language
# toolchains, documents, media and infra CLIs are declared by the machine repos.
{ pkgs, ... }:
{
  home.packages = [
    # Sixel support, which the Homebrew tmux lacks.
    (pkgs.tmux.override { withSixel = true; })

    # Nix ecosystem
    pkgs.cachix
    pkgs.nix-direnv
    pkgs.nixd
    pkgs.treefmt
    pkgs.nixfmt

    # Languages and runtimes
    pkgs.nodejs_latest
    pkgs.python3
    pkgs.lua5_4

    # Language servers and checkers
    pkgs.basedpyright
    pkgs.lua-language-server

    # GNU userland, unprefixed, so GNU sed/awk/grep/tar/make/ls win on PATH.
    pkgs.coreutils
    pkgs.gnused
    pkgs.gnutar
    pkgs.gnugrep
    pkgs.gawk
    pkgs.gnumake

    # CLI tools. interactive.sh initializes mise, fzf, starship, zoxide and
    # atuin unconditionally, so each has to stay in this set.
    pkgs.bat
    pkgs.eza
    pkgs.fd
    pkgs.ripgrep
    pkgs.zoxide
    pkgs.fzf
    pkgs.zsh-fzf-tab
    pkgs.jq
    pkgs.direnv
    pkgs.starship
    pkgs.atuin
    pkgs.tree-sitter
    pkgs.stylua
    pkgs.just
    pkgs.tree
    pkgs.watch
    pkgs.wget
    pkgs.rsync
    pkgs.jujutsu
    pkgs.rip2
    pkgs.difftastic
    pkgs.mise
    pkgs.uv

    # Monitoring
    pkgs.btop
    pkgs.procs

    # Editors
    pkgs.neovim
  ];
}
