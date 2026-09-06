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

    # GNU userland, unprefixed, so GNU sed/awk/grep/tar/make/ls win on PATH.
    pkgs.coreutils
    pkgs.gnused
    pkgs.gnutar
    pkgs.gnugrep
    pkgs.gawk
    pkgs.gnumake

    # CLI tools
    pkgs.bat
    pkgs.eza
    pkgs.fd
    pkgs.ripgrep
    pkgs.zoxide
    pkgs.fzf
    pkgs.zsh-fzf-tab
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
    pkgs.tree
    pkgs.watch
    pkgs.wget
    pkgs.rsync
    pkgs.rlwrap
    pkgs.jujutsu
    pkgs.rip2
    pkgs.difftastic
    # nixpkgs dropped urlview; urlscan is its maintained equivalent.
    pkgs.urlscan
    pkgs.websocat
    pkgs.mise
    pkgs.uv
    pkgs.lazydocker

    # Documents and plotting
    pkgs.graphviz
    pkgs.gnuplot
    pkgs.pandoc
    pkgs.tectonic

    # Media
    pkgs.ffmpeg
    pkgs.imagemagick

    # Monitoring
    pkgs.btop
    pkgs.glances
    pkgs.procs

    # DevOps / infra
    pkgs.awscli2
    pkgs.kubectl
    pkgs.k9s
    pkgs.kubelogin
    pkgs.s3cmd
    pkgs.rclone

    # macOS desktop
    pkgs.terminal-notifier
    pkgs.sketchybar
    pkgs.jankyborders

    # Editors and terminal
    pkgs.neovim
    pkgs.zellij

    # Coding agents
    pkgs.pi-coding-agent
  ];
}
