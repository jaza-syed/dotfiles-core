#!/bin/sh

theme="${1:-}"
session="${2:-$(tmux display-message -p '#{session_name}')}"

# Without an explicit theme, keep an existing session theme first; only then
# consume the shell-resolved DOTFILES_THEME imported into the tmux session.
if [ -z "$theme" ]; then
  theme=$(tmux show-options -qv -t "$session" @theme 2>/dev/null)
fi

if [ -z "$theme" ]; then
  env_theme=$(tmux show-environment -t "$session" DOTFILES_THEME 2>/dev/null || true)
  case "$env_theme" in
    DOTFILES_THEME=*)
      theme=${env_theme#DOTFILES_THEME=}
      ;;
  esac
fi

if [ -z "$theme" ]; then
  theme="light"
fi

theme_file="$HOME/.config/tmux/colors-${theme}.conf"
if [ ! -f "$theme_file" ]; then
  tmux display-message "Unknown tmux theme: ${theme}"
  exit 1
fi

apply_scoped_theme_file() {
  apply_window_option() {
    option=$1
    value=$2

    tmux list-windows -t "$session" -F '#{window_id}' | while IFS= read -r window_id; do
      [ -n "$window_id" ] || continue
      tmux set-window-option -q -t "$window_id" "$option" "$value"
    done
  }

  while IFS= read -r line; do
    case "$line" in
      ""|\#*)
        continue
        ;;
      "set -g "*)
        rest=${line#"set -g "}
        ;;
      "set-option -g "*)
        rest=${line#"set-option -g "}
        ;;
      *)
        continue
        ;;
    esac

    option=${rest%% *}
    value=${rest#"$option" }

    case "$value" in
      \"*\")
        value=${value#\"}
        value=${value%\"}
        ;;
      \'*\')
        value=${value#\'}
        value=${value%\'}
        ;;
    esac

    case "$option" in
      @statusline-*|@pane-label-*|status-style)
        tmux set-option -q -t "$session" "$option" "$value"
        ;;
      window-style|window-active-style|pane-border-style|pane-active-border-style|copy-mode-position-style)
        apply_window_option "$option" "$value"
        ;;
    esac
  done < "$theme_file"
}

tmux set-option -q -t "$session" @theme "$theme"
tmux set-environment -t "$session" DOTFILES_THEME "$theme"
apply_scoped_theme_file
"$HOME/.config/tmux/statusline.sh" apply "$session"
