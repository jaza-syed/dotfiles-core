# Lifecycle steps that install.sh used to run: completion generation, the tmux
# terminfo entry, and TPM plugin clones.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  repo = config.dotfiles.repoDir;
in
{
  imports = [ ./repo.nix ];

  home.activation = {
    # Homebrew must be on PATH so the generator can reach brew- and
    # mise-installed tools; DOTFILES_COMPLETIONS_DIR keeps its usual default.
    dotfilesCompletions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      (
        export PATH="$HOME/.nix-profile/bin:/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
        run "${repo}/scripts/generate_completions.sh"
      )
    '';

    # Colored underlines in Neovim inside tmux need this user terminfo entry.
    tmuxTerminfo = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -e "$HOME/.terminfo/74/tmux-256color" ] && [ ! -e "$HOME/.terminfo/t/tmux-256color" ]; then
        run /usr/bin/tic -x "${repo}/terminfo/tmux-256color.ti"
      fi
    '';

    # Clone TPM and the plugins declared in tmux.conf without starting a server.
    tmuxPlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      tmux_plugins_root="$HOME/.local/share/tmux/plugins"
      tmux_plugins=$(${pkgs.gnused}/bin/sed -n "s/^set -g @plugin '\([^']*\)'$/\1/p" "${repo}/tmux/.config/tmux/tmux.conf")
      for tmux_plugin in $tmux_plugins; do
        tmux_plugin_dir="$tmux_plugins_root/''${tmux_plugin##*/}"
        if [ ! -e "$tmux_plugin_dir" ]; then
          run ${pkgs.git}/bin/git clone "https://github.com/$tmux_plugin" "$tmux_plugin_dir"
        elif [ ! -d "$tmux_plugin_dir/.git" ]; then
          echo "Not a plugin checkout: $tmux_plugin_dir" >&2
          exit 1
        fi
      done
    '';
  };
}
