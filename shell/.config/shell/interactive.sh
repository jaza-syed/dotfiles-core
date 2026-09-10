# shellcheck shell=bash
# Shared interactive shell config — sourced by .zshrc and .bashrc
# Aliases, functions, tool init for interactive use

# Detect shell
if [ -n "$ZSH_VERSION" ]; then
    _shell=zsh
else
    _shell=bash
fi

# --- Shell options ---

# The Claude Code shell snapshot copies this into its Bash tool.
set -o pipefail

# Unmap C-s and C-q (freeze and unfreeze terminal)
stty stop undef
stty start undef

# --- Aliases ---

alias l='eza'
alias la='eza -a'
alias ll='eza -lah'
alias ls='eza --color=auto'
alias g="git"
alias n="nvim"

# Python project checks (ruff + mypy + uv lock consistency)
alias pycheck='ruff check . && mypy && uv lock --check'

# --- Environment ---

export NTS1_URL="https://stream-relay-geo.ntslive.net/stream"
export NTS2_URL="https://stream-relay-geo.ntslive.net/stream2"
export BBCR3_URL="http://lstn.lv/bbcradio.m3u8?station=bbc_radio_three&bitrate=96000"
export EZA_COLORS="di=1:da=0"

# Colorized less/man
export LESS_TERMCAP_mb=$'\e[1;31m'     # begin bold
export LESS_TERMCAP_md=$'\e[1;33m'     # begin blink
export LESS_TERMCAP_so=$'\e[01;44;37m' # begin reverse video
export LESS_TERMCAP_us=$'\e[01;37m'    # begin underline
export LESS_TERMCAP_me=$'\e[0m'        # reset bold/blink
export LESS_TERMCAP_se=$'\e[0m'        # reset reverse video
export LESS_TERMCAP_ue=$'\e[0m'        # reset underline
export GROFF_NO_SGR=1
export MANPAGER='less -s -M +Gg'

# --- Theme helpers ---

load_fzf_theme() {
    local theme_name="${1:-light}"
    local theme_file="$HOME/.config/shell/fzf-theme-${theme_name}.sh"

    if [ ! -f "$theme_file" ]; then
        printf 'Unknown fzf theme: %s\n' "$theme_name" >&2
        return 1
    fi

    # shellcheck disable=SC1090
    . "$theme_file"
}

resolve_theme_name() {
    if [ -n "$DOTFILES_THEME" ]; then
        printf '%s\n' "$DOTFILES_THEME"
        return 0
    fi

    if [ -n "$TMUX" ] && command -v tmux >/dev/null 2>&1; then
        local theme_name

        theme_name="$(tmux show-options -qv @theme 2>/dev/null)"
        if [ -n "$theme_name" ]; then
            printf '%s\n' "$theme_name"
            return 0
        fi
    fi

    # WezTerm: theme is written per-window to /tmp/wezterm-theme-<window_id>
    # by the user-var-changed handler in wezterm.lua. Map our pane to its
    # window via `wezterm cli list` and read the file.
    if [ -n "$WEZTERM_PANE" ] && command -v wezterm >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        local window_id theme_file theme_name
        window_id="$(wezterm cli list --format json 2>/dev/null \
            | jq -r --argjson pid "$WEZTERM_PANE" \
                'map(select(.pane_id == $pid)) | first | .window_id // empty')"
        if [ -n "$window_id" ]; then
            theme_file="/tmp/wezterm-theme-$window_id"
            if [ -r "$theme_file" ]; then
                theme_name="$(cat "$theme_file" 2>/dev/null)"
                if [ -n "$theme_name" ]; then
                    printf '%s\n' "$theme_name"
                    return 0
                fi
            fi
        fi
    fi

    return 1
}

apply_shell_theme() {
    local theme_name="${1:-light}"

    load_fzf_theme "$theme_name" || return 1
    export DOTFILES_THEME="$theme_name"
}

apply_terminal_theme() {
    local theme_name="$1"
    local encoded_theme

    # Neovim's terminal is the emulator here and forwards nothing to WezTerm, so
    # the escape would only be printed. $TMUX is inherited but means nothing.
    [ -n "$NVIM" ] && return 0

    encoded_theme="$(printf '%s' "$theme_name" | base64)"
    if [ -n "$TMUX" ]; then
        # WezTerm user-var via OSC 1337 (SetUserVar), wrapped for tmux passthrough
        printf '\033Ptmux;\033\033]1337;SetUserVar=%s=%s\007\033\\' THEME "$encoded_theme"
    else
        printf '\033]1337;SetUserVar=%s=%s\007' THEME "$encoded_theme"
    fi
}

available_theme_names() {
    local theme_dir="$HOME/.config/shell"
    local theme_file base

    [ -d "$theme_dir" ] || return 0

    find -H "$theme_dir" -name 'fzf-theme-*.sh' -print 2>/dev/null | while IFS= read -r theme_file; do
        base="${theme_file##*/}"
        base="${base#fzf-theme-}"
        base="${base%.sh}"
        [ -n "$base" ] && printf '%s\n' "$base"
    done | sort -u
}

pick_theme_name() {
    local query="${1:-}"
    local theme_names exact_match matches count selection

    theme_names="$(available_theme_names)"
    if [ -z "$theme_names" ]; then
        printf 'No themes found in %s\n' "$HOME/.config/shell" >&2
        return 1
    fi

    if [ -z "$query" ]; then
        if ! command -v fzf >/dev/null 2>&1; then
            printf 'fzf is required to pick a theme\n' >&2
            return 1
        fi

        selection="$(printf '%s\n' "$theme_names" | fzf --height=~40% --layout=reverse --border --prompt='Theme> ')" || return 1
        [ -n "$selection" ] || return 1
        printf '%s\n' "$selection"
        return 0
    fi

    exact_match="$(printf '%s\n' "$theme_names" | grep -i -x -F -- "$query" | head -n 1 || true)"
    if [ -n "$exact_match" ]; then
        printf '%s\n' "$exact_match"
        return 0
    fi

    matches="$(printf '%s\n' "$theme_names" | grep -i -F -- "$query" || true)"
    if [ -z "$matches" ]; then
        printf 'No themes match: %s\n' "$query" >&2
        printf 'Available themes:\n%s\n' "$theme_names" >&2
        return 1
    fi

    count="$(printf '%s\n' "$matches" | wc -l | tr -d '[:space:]')"
    if [ "$count" = "1" ]; then
        printf '%s\n' "$matches"
        return 0
    fi

    if ! command -v fzf >/dev/null 2>&1; then
        printf 'Multiple themes match: %s\n%s\n' "$query" "$matches" >&2
        return 1
    fi

    selection="$(printf '%s\n' "$matches" | fzf --height=~40% --layout=reverse --border --prompt='Theme> ' --query="$query")" || return 1
    [ -n "$selection" ] || return 1
    printf '%s\n' "$selection"
}

# --- Tool init ---

# mise adds project-local tool shims; global tools come from Home Manager
eval "$(mise activate "$_shell")"

startup_theme="$(resolve_theme_name 2>/dev/null || printf '%s' light)"

# Load the session theme before initializing shell-local widgets like fzf.
if ! apply_shell_theme "$startup_theme"; then
    printf 'Failed to load shell theme: %s\n' "$startup_theme" >&2
    startup_theme=light
    apply_shell_theme "$startup_theme" || printf 'Failed to load shell theme: %s\n' "$startup_theme" >&2
fi

# Shell hooks for Home Manager-installed tools
# shellcheck disable=SC1090 # fzf emits its integration at runtime
source <(fzf --"$_shell")
export FZF_CTRL_T_COMMAND='fd --type f --hidden'
eval "$(direnv-instant hook "$_shell")"
eval "$(starship init "$_shell")"
eval "$(zoxide init "$_shell")"
eval "$(atuin init "$_shell" --disable-up-arrow)"

# --- Functions ---

# Pick a ticket file from $TICKETS_DIR and open it in Neovim.
tickets() {
    if [ -z "${TICKETS_DIR:-}" ]; then
        echo "TICKETS_DIR is not set; check ~/.config/shell/env.sh" >&2
        return 1
    fi

    if [ ! -d "$TICKETS_DIR" ]; then
        echo "TICKETS_DIR does not exist: $TICKETS_DIR" >&2
        return 1
    fi

    local file
    file="$(
        cd "$TICKETS_DIR" || exit
        fd --type f --hidden --exclude .git . | fzf --prompt='Tickets> '
    )" || return

    [ -n "$file" ] && nvim -- "$TICKETS_DIR/$file"
}

# Pick/switch theme for the current shell, terminal window, and tmux session.
# No args opens an fzf picker; a query applies exact/single matches or opens a
# picker for multiple partial matches. Nvim detects the new background via
# OSC 11 on <leader>td.
theme() {
    local query theme_name

    query="$*"
    theme_name="$(pick_theme_name "$query")" || return 1
    apply_shell_theme "$theme_name" || return 1

    # Tell wezterm to switch colors for this window. Inside tmux this must be
    # wrapped in a passthrough sequence so the outer terminal actually sees it.
    apply_terminal_theme "$theme_name"

    if [ -n "$TMUX" ]; then
        tmux run-shell "$HOME/.config/tmux/apply-theme.sh '$theme_name' '#{session_name}'"
    fi
}

if [ -n "$TMUX" ]; then
    apply_terminal_theme "$startup_theme"
fi

# Fragment written by the dotfiles.shell.extraInteractive Home Manager option
if [ -f "$HOME/.config/shell/extra.interactive.sh" ]; then
    . "$HOME/.config/shell/extra.interactive.sh"
fi

unset _shell startup_theme
