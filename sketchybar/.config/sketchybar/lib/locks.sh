#!/usr/bin/env bash

# Lock helpers. This file is intended to be sourced after runtime.sh/state.sh.

RENDER_LOCK_HELD=${RENDER_LOCK_HELD:-0}
RELOAD_LOCK_HELD=${RELOAD_LOCK_HELD:-0}

lock_pid() {
  local dir="$1"

  [[ -r "$dir/pid" ]] && tr -d '\n' < "$dir/pid" || true
}

lock_age_seconds() {
  local dir="$1"
  local mtime
  local now

  mtime="$(stat -f %m "$dir" 2>/dev/null || printf '0')"
  now="$(date +%s)"

  if [[ ! "$mtime" =~ ^[0-9]+$ ]]; then
    mtime=0
  fi

  printf '%s' "$((now - mtime))"
}

kill_process_tree() {
  local pid="$1"
  local signal="$2"
  local child

  while IFS= read -r child; do
    if [[ "$child" =~ ^[0-9]+$ ]]; then
      kill_process_tree "$child" "$signal"
    fi
  done < <(pgrep -P "$pid" 2>/dev/null || true)

  kill -"$signal" "$pid" 2>/dev/null || true
}

terminate_lock_owner() {
  local dir="$1"
  local pid
  local command_line

  pid="$(lock_pid "$dir")"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 0
  kill -0 "$pid" 2>/dev/null || return 0

  command_line="$(ps -p "$pid" -o command= 2>/dev/null || true)"
  case "$command_line" in
    *workspaces.sh*|*aerospace_trigger.sh*)
      kill_process_tree "$pid" TERM
      sleep 0.2
      kill_process_tree "$pid" KILL
      ;;
  esac
}

lock_is_stale() {
  local dir="$1"
  local pid
  local age

  [[ -d "$dir" ]] || return 1

  pid="$(lock_pid "$dir")"
  age="$(lock_age_seconds "$dir")"

  if [[ "$pid" =~ ^[0-9]+$ ]] && ! kill -0 "$pid" 2>/dev/null; then
    return 0
  fi

  if [[ "$age" =~ ^[0-9]+$ ]] && (( age >= LOCK_STALE_SECONDS )); then
    return 0
  fi

  return 1
}

acquire_lock() {
  local dir="$1"
  local name="$2"
  local pid
  local age

  if mkdir "$dir" 2>/dev/null; then
    printf '%s\n' "$$" > "$dir/pid"
    printf '%s\n' "$(date +%s)" > "$dir/created_at"
    return 0
  fi

  if lock_is_stale "$dir"; then
    pid="$(lock_pid "$dir")"
    age="$(lock_age_seconds "$dir")"
    log_msg "locks" "recover reason=stale_${name}_lock pid=${pid:-unknown} age=${age:-unknown}s sender=${SENDER:-routine}"
    terminate_lock_owner "$dir"
    rm -rf "$dir" 2>/dev/null || true

    if mkdir "$dir" 2>/dev/null; then
      printf '%s\n' "$$" > "$dir/pid"
      printf '%s\n' "$(date +%s)" > "$dir/created_at"
      return 0
    fi
  fi

  return 1
}

release_lock() {
  local dir="$1"
  local pid

  pid="$(lock_pid "$dir")"
  if [[ "$pid" == "$$" ]]; then
    rm -rf "$dir" 2>/dev/null || true
  fi
}

release_held_locks() {
  if (( RELOAD_LOCK_HELD )); then
    release_lock "$RELOAD_LOCK_DIR"
    RELOAD_LOCK_HELD=0
  fi

  if (( RENDER_LOCK_HELD )); then
    release_lock "$RENDER_LOCK_DIR"
    RENDER_LOCK_HELD=0
  fi
}
