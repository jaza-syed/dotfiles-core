# Bash also sources this file for the non-interactive shells sshd starts, where
# stty and bind have no terminal to act on.
case $- in
    *i*) ;;
    *) return ;;
esac

[[ -f ~/.bash-preexec.sh ]] && source ~/.bash-preexec.sh

# Homebrew, nixpkgs or system bash-completion, plus dotfiles-generated CLI completions.
if [[ -r /opt/homebrew/etc/profile.d/bash_completion.sh ]]; then
    source /opt/homebrew/etc/profile.d/bash_completion.sh
elif [[ -r /usr/local/etc/profile.d/bash_completion.sh ]]; then
    source /usr/local/etc/profile.d/bash_completion.sh
elif [[ -r "$HOME/.nix-profile/share/bash-completion/bash_completion" ]]; then
    source "$HOME/.nix-profile/share/bash-completion/bash_completion"
elif [[ -r /usr/share/bash-completion/bash_completion ]]; then
    source /usr/share/bash-completion/bash_completion
fi

source ~/.config/shell/interactive.sh

_dotfiles_completion_dir="${DOTFILES_COMPLETIONS_DIR:-$HOME/.cache/dotfiles/completions}/bash"
if [[ -d "$_dotfiles_completion_dir" ]]; then
    for _dotfiles_completion in "$_dotfiles_completion_dir"/*.bash; do
        [[ -r "$_dotfiles_completion" ]] && source "$_dotfiles_completion"
    done
fi
unset _dotfiles_completion _dotfiles_completion_dir

# Use fzf as the UI for bash completion candidates, as fzf-tab does in zsh.
_fzf_tab_completion="${XDG_DATA_HOME:-$HOME/.local/share}/fzf-tab-completion/bash/fzf-bash-completion.sh"
if [[ -r "$_fzf_tab_completion" ]]; then
    source "$_fzf_tab_completion"
    bind -x '"\t": fzf_bash_completion'
fi
unset _fzf_tab_completion

# C-x C-e to edit command line in $EDITOR
bind '"\C-x\C-e": edit-and-execute-command'

bind 'set match-hidden-files on'
