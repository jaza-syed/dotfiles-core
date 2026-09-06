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
# shellcheck source=/dev/null
source "$CONFIG_DIR/lib/locks.sh"
# shellcheck source=/dev/null
source "$PLUGIN_DIR/icon_map.sh"

if [[ -r "$BAR_VARIANT_FILE" ]]; then
  BAR_VARIANT="$(tr -d '\n' < "$BAR_VARIANT_FILE" 2>/dev/null || true)"
fi
normalize_bar_variant

log_debug() {
  log_msg "workspaces" "$*"
}

cleanup() {
  local status=$?

  release_held_locks

  if (( status != 0 )); then
    log_debug "error status=$status sender=${SENDER:-unknown} reason=${TRIGGER_REASON:-}"
  fi
}

trap cleanup EXIT

config_state="$([[ -r "$CONFIG_STATE_FILE" ]] && tr -d '\n' < "$CONFIG_STATE_FILE" || true)"
if [[ "$config_state" == loading* ]]; then
  config_started="${config_state#loading }"
  now="$(date +%s)"

  if [[ "$config_started" =~ ^[0-9]+$ ]] && (( now - config_started <= 30 )); then
    log_debug "skip reason=config_loading sender=${SENDER:-routine} state=$config_state"
    exit 0
  fi

  if [[ "$config_started" =~ ^[0-9]+$ ]]; then
    log_debug "continue reason=stale_config_loading sender=${SENDER:-routine} age=$((now - config_started))s state=$config_state"
  else
    log_debug "continue reason=unknown_config_loading sender=${SENDER:-routine} state=$config_state"
  fi
fi

if ! acquire_lock "$RENDER_LOCK_DIR" "render"; then
  log_debug "skip reason=render_in_progress sender=${SENDER:-routine} reason=${TRIGGER_REASON:-}"
  exit 0
fi
RENDER_LOCK_HELD=1

request_reload() {
  local reason="$1"
  local detail="${2:-}"
  local now
  local last_reload
  local status

  if ! acquire_lock "$RELOAD_LOCK_DIR" "reload"; then
    log_debug "skip reason=reload_in_progress sender=${SENDER:-routine} reload_reason=$reason $detail"
    exit 0
  fi
  RELOAD_LOCK_HELD=1

  now="$(date +%s)"
  last_reload="$([[ -r "$RELOAD_DEBOUNCE_FILE" ]] && tr -d '\n' < "$RELOAD_DEBOUNCE_FILE" || true)"

  if [[ "$last_reload" =~ ^[0-9]+$ ]] && (( now - last_reload < RELOAD_DEBOUNCE_SECONDS )); then
    log_debug "skip reason=reload_debounced sender=${SENDER:-routine} reload_reason=$reason age=$((now - last_reload))s $detail"
    release_lock "$RELOAD_LOCK_DIR"
    RELOAD_LOCK_HELD=0
    exit 0
  fi

  printf '%s\n' "$now" > "$RELOAD_DEBOUNCE_FILE"
  state_mark_loading "$now"
  log_debug "reload reason=$reason sender=${SENDER:-routine} $detail"

  if run_sketchybar_command "$SKETCHYBAR_BIN" --reload; then
    status=0
  else
    status=$?
  fi

  release_lock "$RELOAD_LOCK_DIR"
  RELOAD_LOCK_HELD=0
  exit "$status"
}

load_monitor_ids() {
  local saved_monitors
  local live_monitors

  if [[ -f "$CURRENT_TOPOLOGY_FILE" ]]; then
    awk -F'|' 'NF && $1 != "" { print $1 }' "$CURRENT_TOPOLOGY_FILE"
    return 0
  fi

  saved_monitors="$(read_saved_lines "$MONITORS_FILE")"
  if [[ -n "$saved_monitors" ]]; then
    printf '%s\n' "$saved_monitors"
  else
    live_monitors="$(aerospace_query list-monitors --format '%{monitor-id}' || true)"
    [[ -n "$live_monitors" ]] && printf '%s\n' "$live_monitors"
  fi
}

load_workspaces() {
  local live_workspaces
  local saved_workspaces

  live_workspaces="$(aerospace_query list-workspaces --all --format '%{workspace}' || true)"
  if [[ -n "$live_workspaces" ]]; then
    printf '%s\n' "$live_workspaces"
  else
    saved_workspaces="$(read_saved_lines "$WORKSPACES_FILE")"
    if [[ -n "$saved_workspaces" ]]; then
      printf '%s\n' "$saved_workspaces"
    else
      default_workspaces_string
    fi
  fi
}

hide_all() {
  local cmd=("$SKETCHYBAR_BIN")
  local monitor ws slot window_item

  for monitor in "${MONITOR_IDS[@]}"; do
    cmd+=(--set "group.workspaces.$monitor" drawing=off)

    for ws in "${WORKSPACES[@]}"; do
      cmd+=(
        --set "group.workspace.$monitor.$ws"
        drawing=off
        background.color="$CHIP_INACTIVE_BG"
        --set "workspace.$monitor.$ws"
        drawing=off
        label=
        label.drawing=off
        icon.highlight=off
        label.highlight=off
        --set "workspace.$monitor.$ws.separator"
        drawing=off
        icon.highlight=off
        icon.color="$WINDOW_INACTIVE_COLOR"
        --set "workspace.$monitor.$ws.trailing"
        drawing=off
      )

      for (( slot = 1; slot <= MAX_WINDOWS_PER_WORKSPACE; slot++ )); do
        window_item="workspace.$monitor.$ws.window.$slot"
        cmd+=(
          --set "$window_item"
          drawing=off
          icon=
          icon.color="$WINDOW_INACTIVE_COLOR"
          click_script=
        )
      done
    done
  done

  if (( ${#cmd[@]} > 1 )); then
    run_sketchybar_command "${cmd[@]}"
  fi
}

MONITOR_IDS=()
while IFS= read -r monitor_id; do
  [[ -n "$monitor_id" ]] && MONITOR_IDS+=("$monitor_id")
done < <(load_monitor_ids)

WORKSPACES=()
while IFS= read -r workspace_name; do
  [[ -n "$workspace_name" ]] && WORKSPACES+=("$workspace_name")
done < <(load_workspaces)

if (( ${#WORKSPACES[@]} == 0 )); then
  WORKSPACES=("${DEFAULT_WORKSPACES[@]}")
fi

if [[ ! -x "$AEROSPACE_BIN" ]] && ! command -v aerospace >/dev/null 2>&1; then
  log_debug "hide reason=aerospace_missing sender=${SENDER:-routine} path=$PATH"
  hide_all
  exit 0
fi

live_monitor_snapshot="$(aerospace_query list-monitors --format '%{monitor-id}' || true)"
live_workspace_snapshot="$(aerospace_query list-workspaces --all --format '%{workspace}' || true)"
saved_monitor_snapshot="$(read_saved_lines "$ALL_MONITORS_FILE")"
saved_workspace_snapshot="$(read_saved_lines "$WORKSPACES_FILE")"

if [[ -n "$live_monitor_snapshot" && -n "$saved_monitor_snapshot" && "$live_monitor_snapshot" != "$saved_monitor_snapshot" ]]; then
  request_reload "monitor_topology_change" "monitors=$live_monitor_snapshot saved=$saved_monitor_snapshot"
fi

if [[ -n "$live_workspace_snapshot" && -n "$saved_workspace_snapshot" && "$live_workspace_snapshot" != "$saved_workspace_snapshot" ]]; then
  request_reload "workspace_topology_change" "workspaces=$live_workspace_snapshot saved=$saved_workspace_snapshot"
fi

if (( ${#MONITOR_IDS[@]} == 0 )); then
  log_debug "hide reason=no_monitors sender=${SENDER:-routine} reason=${TRIGGER_REASON:-}"
  hide_all
  exit 0
fi

write_words_file "$MONITORS_FILE" "${MONITOR_IDS[@]}"
if [[ -n "$live_monitor_snapshot" ]]; then
  printf '%s\n' "$live_monitor_snapshot" | atomic_write "$ALL_MONITORS_FILE"
fi
write_words_file "$WORKSPACES_FILE" "${WORKSPACES[@]}"

window_lines="$(aerospace_query list-windows --all --format '%{window-id}|%{workspace}|%{monitor-id}|%{app-name}' || true)"
focused_window_id="$(aerospace_query list-windows --focused --format '%{window-id}' | head -n 1 || true)"

workspace_var_suffix() {
  local monitor_id="$1"
  local workspace_name="$2"

  printf '%s_%s' \
    "${monitor_id//[^A-Za-z0-9]/_}" \
    "${workspace_name//[^A-Za-z0-9]/_}"
}

visible_workspace_var() {
  local monitor_id="$1"
  printf 'visible_workspace_%s' "${monitor_id//[^A-Za-z0-9]/_}"
}

set_visible_workspace() {
  local monitor_id="$1"
  local workspace_name="$2"
  local var_name

  var_name="$(visible_workspace_var "$monitor_id")"
  printf -v "$var_name" '%s' "$workspace_name"
}

get_visible_workspace() {
  local monitor_id="$1"
  local var_name

  var_name="$(visible_workspace_var "$monitor_id")"
  printf '%s' "${!var_name:-}"
}

mark_workspace_has_windows() {
  local monitor_id="$1"
  local workspace_name="$2"
  local suffix
  local var_name

  suffix="$(workspace_var_suffix "$monitor_id" "$workspace_name")"
  var_name="workspace_has_windows_$suffix"

  printf -v "$var_name" '%s' 1
}

workspace_has_windows() {
  local monitor_id="$1"
  local workspace_name="$2"
  local suffix
  local var_name

  suffix="$(workspace_var_suffix "$monitor_id" "$workspace_name")"
  var_name="workspace_has_windows_$suffix"

  [[ -n "${!var_name:-}" ]]
}

set_workspace_window_slot() {
  local monitor_id="$1"
  local workspace_name="$2"
  local slot="$3"
  local window_id="$4"
  local glyph="$5"
  local suffix
  local icon_var
  local id_var

  suffix="$(workspace_var_suffix "$monitor_id" "$workspace_name")"
  icon_var="workspace_window_icon_${suffix}_${slot}"
  id_var="workspace_window_id_${suffix}_${slot}"

  printf -v "$icon_var" '%s' "$glyph"
  printf -v "$id_var" '%s' "$window_id"
}

append_workspace_window() {
  local monitor_id="$1"
  local workspace_name="$2"
  local window_id="$3"
  local glyph="$4"
  local suffix
  local count_var
  local count

  suffix="$(workspace_var_suffix "$monitor_id" "$workspace_name")"
  count_var="workspace_window_count_$suffix"
  count="${!count_var:-0}"

  count=$((count + 1))
  printf -v "$count_var" '%s' "$count"

  if (( count <= MAX_WINDOWS_PER_WORKSPACE )); then
    set_workspace_window_slot "$monitor_id" "$workspace_name" "$count" "$window_id" "$glyph"
  elif [[ -n "$focused_window_id" && "$window_id" == "$focused_window_id" ]]; then
    set_workspace_window_slot "$monitor_id" "$workspace_name" "$MAX_WINDOWS_PER_WORKSPACE" "$window_id" "$glyph"
  fi
}

get_workspace_window_count() {
  local monitor_id="$1"
  local workspace_name="$2"
  local suffix
  local var_name

  suffix="$(workspace_var_suffix "$monitor_id" "$workspace_name")"
  var_name="workspace_window_count_$suffix"

  printf '%s' "${!var_name:-0}"
}

get_workspace_window_icon() {
  local monitor_id="$1"
  local workspace_name="$2"
  local slot="$3"
  local suffix
  local var_name

  suffix="$(workspace_var_suffix "$monitor_id" "$workspace_name")"
  var_name="workspace_window_icon_${suffix}_${slot}"

  printf '%s' "${!var_name:-}"
}

get_workspace_window_id() {
  local monitor_id="$1"
  local workspace_name="$2"
  local slot="$3"
  local suffix
  local var_name

  suffix="$(workspace_var_suffix "$monitor_id" "$workspace_name")"
  var_name="workspace_window_id_${suffix}_${slot}"

  printf '%s' "${!var_name:-}"
}

for monitor in "${MONITOR_IDS[@]}"; do
  set_visible_workspace "$monitor" "$(aerospace_query list-workspaces --monitor "$monitor" --visible --format '%{workspace}' | head -n 1 || true)"
done

while IFS='|' read -r window_id workspace monitor_id app_name; do
  [[ -z "${window_id:-}" || -z "${workspace:-}" || -z "${monitor_id:-}" || -z "${app_name:-}" ]] && continue

  mark_workspace_has_windows "$monitor_id" "$workspace"
  app_glyph="$(app_icon "$app_name")"
  append_workspace_window "$monitor_id" "$workspace" "$window_id" "$app_glyph"
done <<< "$window_lines"

cmd=("$SKETCHYBAR_BIN")
monitor_summaries=()

for monitor in "${MONITOR_IDS[@]}"; do
  visible_count=0
  visible_workspaces=()
  focused_workspace="$(get_visible_workspace "$monitor")"

  for ws in "${WORKSPACES[@]}"; do
    if [[ "$ws" == "$focused_workspace" ]] || workspace_has_windows "$monitor" "$ws"; then
      visible_count=$((visible_count + 1))
      visible_workspaces+=("$ws")
      window_count="$(get_workspace_window_count "$monitor" "$ws")"
      label_string=""
      label_drawing=off
      separator_drawing=off
      separator_color="$WINDOW_INACTIVE_COLOR"
      trailing_drawing=off
      background_color="$CHIP_INACTIVE_BG"
      highlight=off

      if (( window_count > 0 )); then
        if [[ "$BAR_VARIANT" == "vertical" ]]; then
          separator_drawing=on
        else
          label_string="|"
          label_drawing=on
        fi
      fi

      if [[ "$BAR_VARIANT" == "vertical" ]]; then
        trailing_drawing=on
      fi

      if [[ "$ws" == "$focused_workspace" ]]; then
        background_color="$CHIP_ACTIVE_BG"
        separator_color="$SEPARATOR_COLOR"
        highlight=on
      fi

      cmd+=(
        --set "group.workspace.$monitor.$ws"
        drawing=on
        background.color="$background_color"
        --set "workspace.$monitor.$ws"
        drawing=on
        label="$label_string"
        label.drawing="$label_drawing"
        icon.highlight="$highlight"
        label.highlight="$highlight"
        --set "workspace.$monitor.$ws.separator"
        drawing="$separator_drawing"
        icon.highlight="$highlight"
        icon.color="$separator_color"
        --set "workspace.$monitor.$ws.trailing"
        drawing="$trailing_drawing"
      )

      for (( slot = 1; slot <= MAX_WINDOWS_PER_WORKSPACE; slot++ )); do
        window_item="workspace.$monitor.$ws.window.$slot"

        if (( slot <= window_count )); then
          window_icon="$(get_workspace_window_icon "$monitor" "$ws" "$slot")"
          window_id="$(get_workspace_window_id "$monitor" "$ws" "$slot")"

          if [[ -n "$window_icon" && -n "$window_id" ]]; then
            window_color="$WINDOW_INACTIVE_COLOR"

            if [[ -n "$focused_window_id" && "$window_id" == "$focused_window_id" ]]; then
              window_color="$WINDOW_FOCUSED_COLOR"
            fi

            cmd+=(
              --set "$window_item"
              drawing=on
              icon="$window_icon"
              icon.color="$window_color"
              click_script="aerospace focus --window-id $window_id"
            )
          else
            cmd+=(
              --set "$window_item"
              drawing=off
              icon=
              icon.color="$WINDOW_INACTIVE_COLOR"
              click_script=
            )
          fi
        else
          cmd+=(
            --set "$window_item"
            drawing=off
            icon=
            icon.color="$WINDOW_INACTIVE_COLOR"
            click_script=
          )
        fi
      done
    else
      cmd+=(
        --set "group.workspace.$monitor.$ws"
        drawing=off
        background.color="$CHIP_INACTIVE_BG"
        --set "workspace.$monitor.$ws"
        drawing=off
        label=
        label.drawing=off
        icon.highlight=off
        label.highlight=off
        --set "workspace.$monitor.$ws.separator"
        drawing=off
        icon.highlight=off
        icon.color="$WINDOW_INACTIVE_COLOR"
        --set "workspace.$monitor.$ws.trailing"
        drawing=off
      )

      for (( slot = 1; slot <= MAX_WINDOWS_PER_WORKSPACE; slot++ )); do
        window_item="workspace.$monitor.$ws.window.$slot"
        cmd+=(
          --set "$window_item"
          drawing=off
          icon=
          icon.color="$WINDOW_INACTIVE_COLOR"
          click_script=
        )
      done
    fi
  done

  if (( visible_count > 0 )); then
    cmd+=(--set "group.workspaces.$monitor" drawing=on)
  else
    cmd+=(--set "group.workspaces.$monitor" drawing=off)
  fi

  if (( ${#visible_workspaces[@]} > 0 )); then
    visible_summary="${visible_workspaces[*]}"
  else
    visible_summary="none"
  fi

  monitor_summaries+=("$monitor:$focused_workspace:$visible_summary")
done

log_debug \
  "render sender=${SENDER:-routine} reason=${TRIGGER_REASON:-} monitors=${monitor_summaries[*]:-none} event_focused=${FOCUSED_WORKSPACE:-} prev=${PREV_WORKSPACE:-} window=${FOCUSED_WINDOW:-}"

if (( ${#cmd[@]} > 1 )); then
  run_sketchybar_command "${cmd[@]}"
fi
