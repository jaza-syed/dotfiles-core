#!/usr/bin/env bash

# Shared runtime helpers for SketchyBar scripts.
# This file is intended to be sourced, not executed.

RUNTIME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${CONFIG_DIR:-$(cd "$RUNTIME_DIR/.." && pwd)}"
PLUGIN_DIR="$CONFIG_DIR/plugins"
LIB_DIR="$CONFIG_DIR/lib"
ITEMS_DIR="$CONFIG_DIR/items"
RENDER_DIR="$CONFIG_DIR/render"

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

BAR_NAME_CURRENT="${BAR_NAME:-sketchybar}"
BAR_STATE_NAME="$(printf '%s' "$BAR_NAME_CURRENT" | tr -c 'A-Za-z0-9_.-' '_')"
STATE_PREFIX="/tmp/$BAR_STATE_NAME"
LOG_FILE="${LOG_FILE:-/tmp/aerospace-sketchybar.log}"

SKETCHYBAR_BIN="${SKETCHYBAR_BIN:-$(command -v "$BAR_NAME_CURRENT" 2>/dev/null || command -v sketchybar 2>/dev/null || echo /opt/homebrew/bin/sketchybar)}"
AEROSPACE_BIN="${AEROSPACE_BIN:-$(command -v aerospace 2>/dev/null || echo /opt/homebrew/bin/aerospace)}"
export SKETCHYBAR_BIN AEROSPACE_BIN CONFIG_DIR PLUGIN_DIR

AEROSPACE_TIMEOUT_SECONDS="${AEROSPACE_TIMEOUT_SECONDS:-3}"
SKETCHYBAR_TIMEOUT_SECONDS="${SKETCHYBAR_TIMEOUT_SECONDS:-5}"
SWIFT_TIMEOUT_SECONDS="${SWIFT_TIMEOUT_SECONDS:-5}"
TIMEOUT_BIN="$(command -v gtimeout 2>/dev/null || command -v timeout 2>/dev/null || true)"

log_msg() {
  local component="$1"
  shift

  printf '%s [%s:%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$component" "$$" "$*" >> "$LOG_FILE"
}

run_with_timeout() {
  local timeout_seconds="$1"
  shift

  if [[ -n "$TIMEOUT_BIN" ]]; then
    "$TIMEOUT_BIN" --kill-after=1s "${timeout_seconds}s" "$@"
  else
    "$@"
  fi
}

aerospace_query() {
  local status

  if run_with_timeout "$AEROSPACE_TIMEOUT_SECONDS" "$AEROSPACE_BIN" "$@" 2>/dev/null; then
    return 0
  fi

  status=$?
  if (( status == 124 || status == 137 )); then
    log_msg "aerospace" "timeout command=$AEROSPACE_BIN $*"
  fi

  return "$status"
}

sb() {
  "$SKETCHYBAR_BIN" "$@"
}

run_sketchybar_command() {
  local status

  if run_with_timeout "$SKETCHYBAR_TIMEOUT_SECONDS" "$@"; then
    return 0
  fi

  status=$?
  if (( status == 124 || status == 137 )); then
    log_msg "sketchybar" "timeout command=$*"
  fi

  return "$status"
}
