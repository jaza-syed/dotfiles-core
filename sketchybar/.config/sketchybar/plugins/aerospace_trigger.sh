#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${CONFIG_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# shellcheck source=/dev/null
source "$CONFIG_DIR/lib/runtime.sh"
# shellcheck source=/dev/null
source "$CONFIG_DIR/lib/settings.sh"
# shellcheck source=/dev/null
source "$CONFIG_DIR/lib/state.sh"

PRIMARY_BAR_NAME=sketchybar
PRIMARY_STATE_PREFIX="/tmp/$PRIMARY_BAR_NAME"
PRIMARY_CONFIG_STATE_FILE="$PRIMARY_STATE_PREFIX-config-state"

log_event() {
  log_msg "aerospace-trigger" "$*"
}

find_sketchybar() {
  local candidate
  local from_path

  from_path="$(command -v sketchybar 2>/dev/null || true)"

  for candidate in \
    "${SKETCHYBAR_BIN:-}" \
    "$from_path" \
    /opt/homebrew/bin/sketchybar \
    /usr/local/bin/sketchybar
  do
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

find_sketchybar_targets() {
  local primary

  primary="$(find_sketchybar || true)"
  if [[ -n "$primary" ]]; then
    printf '%s|%s\n' "$PRIMARY_BAR_NAME" "$primary"
  fi

  if [[ -x "$OFFSET_BAR_BIN" ]] && [[ -n "$("$OFFSET_BAR_BIN" --query displays 2>/dev/null || true)" ]]; then
    printf '%s|%s\n' "$OFFSET_BAR_NAME" "$OFFSET_BAR_BIN"
  fi
}

trigger_event() {
  local event_name="$1"
  local reason="${2:-unknown}"
  local focused_workspace="${AEROSPACE_FOCUSED_WORKSPACE:-}"
  local prev_workspace="${AEROSPACE_PREV_WORKSPACE:-}"
  local focused_window="${AEROSPACE_WINDOW_ID:-}"
  local bar_name
  local sketchybar_bin
  local status
  local failed=0
  local target_count=0

  log_event \
    "trigger start event=$event_name reason=$reason focused_workspace=$focused_workspace prev_workspace=$prev_workspace window_id=$focused_window PATH=$PATH"

  while IFS='|' read -r bar_name sketchybar_bin; do
    [[ -n "$bar_name" && -n "$sketchybar_bin" ]] || continue
    target_count=$((target_count + 1))

    if BAR_NAME="$bar_name" \
      SKETCHYBAR_BIN="$sketchybar_bin" \
      "$sketchybar_bin" --trigger "$event_name" \
        "TRIGGER_REASON=$reason" \
        "FOCUSED_WORKSPACE=$focused_workspace" \
        "PREV_WORKSPACE=$prev_workspace" \
        "FOCUSED_WINDOW=$focused_window"
    then
      log_event "trigger ok bar=$bar_name event=$event_name reason=$reason"
    else
      status=$?
      failed=$status
      log_event "trigger failed bar=$bar_name event=$event_name reason=$reason status=$status"
    fi
  done < <(find_sketchybar_targets)

  if (( target_count == 0 )); then
    log_event "trigger skipped event=$event_name reason=$reason error=no_sketchybar_targets"
  fi

  if (( failed != 0 )); then
    exit "$failed"
  fi
}

bootstrap() {
  local sketchybar_bin

  sketchybar_bin="$(find_sketchybar || true)"

  log_event "bootstrap start bin=${sketchybar_bin:-missing} PATH=$PATH"

  if [[ -z "$sketchybar_bin" ]]; then
    log_event "bootstrap failed error=sketchybar_missing PATH=$PATH"
    exit 1
  fi

  printf 'loading %s\n' "$(date +%s)" > "$PRIMARY_CONFIG_STATE_FILE"

  if "$sketchybar_bin" --reload; then
    log_event "bootstrap reload_ok refresh=deferred_to_sketchybarrc_update"
  else
    local status=$?
    log_event "bootstrap reload_failed status=$status"
    exit "$status"
  fi
}

case "${1:-}" in
  bootstrap)
    bootstrap
    ;;
  trigger)
    if [[ -z "${2:-}" ]]; then
      log_event "error mode=trigger reason=missing_event"
      exit 1
    fi

    trigger_event "$2" "${3:-unknown}"
    ;;
  *)
    log_event "error reason=bad_usage argv=$*"
    exit 1
    ;;
esac
