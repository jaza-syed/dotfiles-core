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
    "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/fzf-tab/share/fzf-tab/fzf-tab.zsh" \
    /usr/local/opt/fzf-tab/share/fzf-tab/fzf-tab.zsh; do
    if [[ -r "$_fzf_tab_plugin" ]]; then
        source "$_fzf_tab_plugin"
        break
    fi
done
unset _fzf_tab_plugin

_dotfiles_find_command() {
    emulate -L zsh
    zmodload zsh/parameter 2>/dev/null

    local name="$1" cmd_path
    cmd_path="${commands[$name]-}"
    [[ -n "$cmd_path" ]] || cmd_path="$(whence -p -- "$name" 2>/dev/null)"
    print -r -- "$cmd_path"
}

# Capture mise-managed tool paths while PATH is known-good during shell startup.
_dotfiles_fzf_bin="$(_dotfiles_find_command fzf)"
_dotfiles_fzf_tmux_bin="$(_dotfiles_find_command fzf-tmux)"
_dotfiles_zoxide_bin="$(_dotfiles_find_command zoxide)"

_dotfiles_ensure_fzf_zoxide() {
    [[ -n "${_dotfiles_zoxide_bin:-}" ]] || _dotfiles_zoxide_bin="$(_dotfiles_find_command zoxide)"
    [[ -n "${_dotfiles_fzf_bin:-}" ]] || _dotfiles_fzf_bin="$(_dotfiles_find_command fzf)"

    if [[ -z "${_dotfiles_zoxide_bin:-}" ]]; then
        zle -M 'zoxide not found'
        return 1
    fi

    if [[ -z "${_dotfiles_fzf_bin:-}" ]]; then
        zle -M 'fzf not found'
        return 1
    fi
}

_dotfiles_fzf() {
    emulate -L zsh
    setopt no_aliases
    zmodload zsh/parameter 2>/dev/null

    local fzf_bin fzf_tmux_bin
    fzf_bin="${_dotfiles_fzf_bin:-}"
    [[ -n "$fzf_bin" ]] || fzf_bin="$(_dotfiles_find_command fzf)"
    if [[ -z "$fzf_bin" ]]; then
        print -u2 -- 'fzf not found'
        return 127
    fi

    if [[ -n "${TMUX_PANE-}" && ( "${FZF_TMUX:-0}" != 0 || -n "${FZF_TMUX_OPTS-}" ) ]]; then
        fzf_tmux_bin="${_dotfiles_fzf_tmux_bin:-}"
        [[ -n "$fzf_tmux_bin" ]] || fzf_tmux_bin="$(_dotfiles_find_command fzf-tmux)"

        if [[ -n "$fzf_tmux_bin" ]]; then
            local -a tmux_opts
            if [[ -n "${FZF_TMUX_OPTS-}" ]]; then
                tmux_opts=(${(z)FZF_TMUX_OPTS})
            else
                tmux_opts=(-d"${FZF_TMUX_HEIGHT:-40%}")
            fi
            "$fzf_tmux_bin" "${tmux_opts[@]}" -- "$@"
            return
        fi
    fi

    "$fzf_bin" "$@"
}

_dotfiles_fzf_defaults() {
    if (( $+functions[__fzf_defaults] )); then
        __fzf_defaults "$@"
    else
        print -r -- "${FZF_DEFAULT_OPTS-} $1 $2"
    fi
}

_dotfiles_pick_zoxide_dir() {
    emulate -L zsh
    setopt pipefail no_aliases

    local fzf_default_opts zoxide_bin
    zoxide_bin="${_dotfiles_zoxide_bin:-}"
    [[ -n "$zoxide_bin" ]] || zoxide_bin="$(_dotfiles_find_command zoxide)"
    [[ -n "$zoxide_bin" ]] || return 127
    fzf_default_opts="$(_dotfiles_fzf_defaults '--reverse --scheme=path' "${_ZO_FZF_OPTS-} +m --no-sort --prompt='zoxide> '")"

    "$zoxide_bin" query -l 2>/dev/null |
        FZF_DEFAULT_COMMAND='' \
        FZF_DEFAULT_OPTS="$fzf_default_opts" \
        FZF_DEFAULT_OPTS_FILE='' \
            _dotfiles_fzf
}

# C-g: pick a zoxide directory and insert it at the cursor without running the command.
zoxide-insert-widget() {
    emulate -L zsh

    _dotfiles_ensure_fzf_zoxide || return 1

    local dir
    zle -I
    dir="$(_dotfiles_pick_zoxide_dir)" || {
        zle redisplay
        return 0
    }

    [[ -n "$dir" ]] || {
        zle redisplay
        return 0
    }

    LBUFFER+="${(q)dir} "
    zle redisplay
}
zle -N zoxide-insert-widget
bindkey '^G' zoxide-insert-widget
bindkey -M emacs '^G' zoxide-insert-widget
bindkey -M viins '^G' zoxide-insert-widget
bindkey -M vicmd '^G' zoxide-insert-widget

# C-k: pick a zoxide directory, then pick file(s) under it like fzf's Ctrl-T.
zoxide-file-widget() {
    emulate -L zsh
    setopt pipefail no_aliases

    _dotfiles_ensure_fzf_zoxide || return 1

    local dir selected item selected_path fzf_default_opts
    zle -I
    dir="$(_dotfiles_pick_zoxide_dir)" || {
        zle redisplay
        return 0
    }

    [[ -n "$dir" && -d "$dir" ]] || {
        zle redisplay
        return 0
    }
    dir="${dir:A}"

    fzf_default_opts="$(_dotfiles_fzf_defaults '--reverse --scheme=path' "${FZF_CTRL_T_OPTS-} -m")"

    selected="$(
        FZF_DEFAULT_COMMAND="fd --hidden --follow --base-directory ${(q)dir}" \
        FZF_DEFAULT_OPTS="$fzf_default_opts" \
        FZF_DEFAULT_OPTS_FILE='' \
            _dotfiles_fzf --header="$dir" < /dev/tty
    )" || {
        zle redisplay
        return 0
    }

    for item in ${(f)selected}; do
        [[ -n "$item" ]] || continue
        if [[ "$item" = /* ]]; then
            selected_path="$item"
        else
            selected_path="${dir%/}/$item"
        fi
        LBUFFER+="${(q)selected_path} "
    done

    zle redisplay
}
zle -N zoxide-file-widget
bindkey '^Y' zoxide-file-widget
bindkey -M emacs '^Y' zoxide-file-widget
bindkey -M viins '^Y' zoxide-file-widget
bindkey -M vicmd '^Y' zoxide-file-widget

# C-x C-e to edit current command in $EDITOR
autoload -z edit-command-line
zle -N edit-command-line
bindkey "^X^E" edit-command-line
