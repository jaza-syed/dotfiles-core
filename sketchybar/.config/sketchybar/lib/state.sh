#!/usr/bin/env bash

# State file helpers. This file is intended to be sourced after runtime.sh.

BAR_VARIANT_FILE="$STATE_PREFIX-bar-variant"
MONITORS_FILE="$STATE_PREFIX-workspace-monitors"
ALL_MONITORS_FILE="$STATE_PREFIX-all-workspace-monitors"
WORKSPACES_FILE="$STATE_PREFIX-workspace-names"
CONFIG_STATE_FILE="$STATE_PREFIX-config-state"
CURRENT_TOPOLOGY_FILE="$STATE_PREFIX-topology.tsv"
ALL_TOPOLOGY_FILE="$STATE_PREFIX-all-topology.tsv"

RELOAD_DEBOUNCE_FILE="$STATE_PREFIX-reload-last"
RELOAD_LOCK_DIR="$STATE_PREFIX-reload.lock"
RENDER_LOCK_DIR="$STATE_PREFIX-workspaces-render.lock"
RELOAD_DEBOUNCE_SECONDS=5
LOCK_STALE_SECONDS=30

atomic_write() {
  local file="$1"
  local tmp

  tmp="$(mktemp "${file}.XXXXXX")"
  cat > "$tmp"
  mv "$tmp" "$file"
}

write_words_file() {
  local file="$1"
  shift

  {
    local word
    for word in "$@"; do
      [[ -n "$word" ]] && printf '%s\n' "$word"
    done
  } | atomic_write "$file"
}

write_text_file() {
  local file="$1"
  local text="${2:-}"

  printf '%s\n' "$text" | atomic_write "$file"
}

read_saved_lines() {
  local file="$1"
  local line

  [[ -f "$file" ]] || return 0

  while IFS= read -r line; do
    [[ -n "$line" ]] && printf '%s\n' "$line"
  done < "$file"
}

state_mark_loading() {
  local timestamp="${1:-$(date +%s)}"
  printf 'loading %s\n' "$timestamp" | atomic_write "$CONFIG_STATE_FILE"
}

state_mark_ready() {
  local timestamp="${1:-$(date +%s)}"
  printf 'ready %s\n' "$timestamp" | atomic_write "$CONFIG_STATE_FILE"
}
