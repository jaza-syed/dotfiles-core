# Nix-owned package set: the globally wanted tools that the repo-wide mise
# config used to install. mise stays for project-local use.
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

    # Languages and runtimes. zig (master builds) and ghcup have no reasonable
    # nixpkgs equivalent and stay project-local.
    pkgs.nodejs_latest
    pkgs.bun
    pkgs.go
    pkgs.ruby
    pkgs.python3
    pkgs.lua5_4
    pkgs.rustc
    pkgs.cargo
    pkgs.rustfmt
    pkgs.clippy
    pkgs.kotlin
    pkgs.gradle
    pkgs.clojure
    pkgs.erlang
    pkgs.elixir
    pkgs.pixi

    # Language servers and checkers
    pkgs.basedpyright
    pkgs.elmPackages.elm-language-server
    pkgs.lua-language-server

    # CLI tools
    pkgs.bat
    pkgs.eza
    pkgs.fd
    pkgs.ripgrep
    pkgs.zoxide
    pkgs.fzf
    pkgs.jq
    pkgs.glab
    pkgs.direnv
    pkgs.starship
    pkgs.atuin
    pkgs.cmake
    pkgs.tree-sitter
    pkgs.stylua
    pkgs.just
    pkgs.mani

    # Editors and terminal
    pkgs.neovim
    pkgs.zellij

    # Coding agents
    pkgs.pi-coding-agent
  ];
}
