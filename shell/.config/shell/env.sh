# shellcheck shell=sh
# Shared environment — sourced by .zshenv and .profile
# Keep lightweight: PATH and env vars only, no tool init or aliases

export EDITOR=nvim
export HOMEBREW_NO_AUTO_UPDATE=1

# Homebrew
if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi
# Home Manager profile ahead of Homebrew and system paths
export PATH="$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# Fragment written by the dotfiles.shell.extraEnv Home Manager option
if [ -f "$HOME/.config/shell/extra.env.sh" ]; then
    . "$HOME/.config/shell/extra.env.sh"
fi

# Optional machine-local/private environment overrides
if [ -f "$HOME/.config/shell/env.local.sh" ]; then
    . "$HOME/.config/shell/env.local.sh"
fi
