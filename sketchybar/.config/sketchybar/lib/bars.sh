#!/usr/bin/env bash

# Bar instance and geometry-group helpers. Intended to be sourced.

ensure_offset_bar() {
  ln -sf "$SKETCHYBAR_BIN" "$OFFSET_BAR_BIN" 2>/dev/null || true

  if [[ ! -x "$OFFSET_BAR_BIN" ]]; then
    log_msg "bars" "offset_bar_unavailable path=$OFFSET_BAR_BIN"
    return 0
  fi

  if [[ -n "$("$OFFSET_BAR_BIN" --query displays 2>/dev/null || true)" ]]; then
    nohup env SKETCHYBAR_BIN="$OFFSET_BAR_BIN" BAR_NAME="$OFFSET_BAR_NAME" \
      "$OFFSET_BAR_BIN" --reload "$CONFIG_DIR/sketchybarrc" >/tmp/$OFFSET_BAR_NAME.log 2>&1 &
    log_msg "bars" "offset_bar_reload name=$OFFSET_BAR_NAME"
  else
    nohup env SKETCHYBAR_BIN="$OFFSET_BAR_BIN" BAR_NAME="$OFFSET_BAR_NAME" \
      "$OFFSET_BAR_BIN" --config "$CONFIG_DIR/sketchybarrc" >/tmp/$OFFSET_BAR_NAME.log 2>&1 &
    log_msg "bars" "offset_bar_start name=$OFFSET_BAR_NAME"
  fi
}

prepare_current_bar_topology() {
  local all_topology="$1"
  local primary_topology
  local offset_topology
  local primary_count
  local offset_count

  CURRENT_TOPOLOGY="$all_topology"
  BAR_GEOMETRY_GROUP=all

  if [[ "$BAR_VARIANT" != "vertical" || -z "$all_topology" ]]; then
    return 0
  fi

  primary_topology="$(topology_filter_group "$all_topology" primary)"
  offset_topology="$(topology_filter_group "$all_topology" offset)"
  primary_count="$(topology_count "$primary_topology")"
  offset_count="$(topology_count "$offset_topology")"

  if [[ "$BAR_NAME_CURRENT" == "$OFFSET_BAR_NAME" ]]; then
    CURRENT_TOPOLOGY="$offset_topology"
    BAR_GEOMETRY_GROUP=offset
    BAR_Y_OFFSET=$OFFSET_BAR_Y_OFFSET
    return 0
  fi

  CURRENT_TOPOLOGY="$primary_topology"
  BAR_GEOMETRY_GROUP=primary
  BAR_Y_OFFSET=0

  if (( offset_count > 0 )); then
    ensure_offset_bar
  fi
}

configure_bar() {
  local display_list="$1"
  local hidden="${2:-off}"

  if [[ -z "$display_list" ]]; then
    display_list=all
    hidden=on
  fi

  sb --bar \
    display="$display_list" \
    hidden="$hidden" \
    height="$BAR_HEIGHT" \
    notch_display_height=0 \
    position="$BAR_POSITION" \
    margin="$BAR_MARGIN" \
    x_offset="$BAR_X_OFFSET" \
    y_offset="$BAR_Y_OFFSET" \
    corner_radius=18 \
    color="$BAR_BG" \
    border_color="$BAR_BORDER" \
    border_width=1 \
    blur_radius=18 \
    padding_left=8 \
    padding_right=8
}

configure_defaults() {
  local default

  default=(
    drawing=on
    updates=on
    padding_left=0
    padding_right=0
    icon.font="Liga SFMono Nerd Font:Bold:15.0"
    label.font="SF Pro:Semibold:13.0"
    icon.color=0xffffffff
    label.color=0xffffffff
  )

  sb --default "${default[@]}"
}
