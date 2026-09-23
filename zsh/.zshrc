# Generated completions are local cache artifacts created by scripts/generate_completions.sh.
_dotfiles_completion_cache="${DOTFILES_COMPLETIONS_DIR:-$HOME/.cache/dotfiles/completions}"

if [ -d "$_dotfiles_completion_cache/zsh" ]; then
    fpath=("$_dotfiles_completion_cache/zsh" $fpath)
fi

# Completions shipped by nixpkgs packages.
if [ -d "$HOME/.nix-profile/share/zsh/site-functions" ]; then
    fpath=("$HOME/.nix-profile/share/zsh/site-functions" $fpath)
fi

autoload -Uz compinit
if [ -d "$_dotfiles_completion_cache/zsh" ]; then
    compinit -d "$_dotfiles_completion_cache/zsh/.zcompdump"
else
    compinit
fi

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

unset _dotfiles_completion_cache

bindkey -e

source ~/.config/shell/interactive.sh

# Show hidden files in tab completion
setopt globdots

# Use fzf as the UI for zsh completion candidates.
# Loaded after fzf's shell integration so fzf-tab owns the Tab widget.
zstyle ':fzf-tab:*' use-fzf-default-opts yes
zstyle ':fzf-tab:*' fzf-flags --height=40% --layout=reverse --border
for _fzf_tab_plugin in \
    "$HOME/.nix-profile/share/fzf-tab/fzf-tab.zsh" \
    "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/fzf-tab/share/fzf-tab/fzf-tab.zsh" \
    /usr/local/opt/fzf-tab/share/fzf-tab/fzf-tab.zsh; do
    if [[ -r "$_fzf_tab_plugin" ]]; then
        source "$_fzf_tab_plugin"
        break
    fi
done
unset _fzf_tab_plugin

# C-x C-e to edit current command in $EDITOR
autoload -z edit-command-line
zle -N edit-command-line
bindkey "^X^E" edit-command-line
