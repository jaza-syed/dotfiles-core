#!/usr/bin/env bash
# Show a border only while an AeroSpace sticky mode is active.
set -euo pipefail

source "$HOME/.config/aerospace/mode-borders-light.sh"

mode="${1:-$(aerospace list-modes --current)}"

case "$mode" in
  select)
    active_color="$BORDERS_SELECT_ACTIVE_COLOR"
    width="$BORDERS_SELECT_WIDTH"
    ;;
  move)
    active_color="$BORDERS_MOVE_ACTIVE_COLOR"
    width="$BORDERS_MOVE_WIDTH"
    ;;
  *)
    active_color="$BORDERS_MAIN_ACTIVE_COLOR"
    width="$BORDERS_MAIN_WIDTH"
    ;;
esac

borders \
  active_color="$active_color" \
  inactive_color="$BORDERS_INACTIVE_COLOR" \
  width="$width" \
  style="$BORDERS_STYLE" \
  ax_focus="$BORDERS_AX_FOCUS" \
  hidpi="$BORDERS_HIDPI" \
  >/dev/null 2>&1 &
