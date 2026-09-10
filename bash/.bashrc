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

# C-x C-e to edit command line in $EDITOR
bind '"\C-x\C-e": edit-and-execute-command'

bind 'set match-hidden-files on'
