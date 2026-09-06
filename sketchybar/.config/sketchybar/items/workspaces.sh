#!/usr/bin/env bash

# Static SketchyBar item graph for AeroSpace workspaces. Intended to be sourced.
# Dynamic state is applied by render/workspaces.sh.

add_workspace_cluster() {
  local monitor="$1"
  local display="$2"
  local ws="$3"
  local item="workspace.$monitor.$ws"
  local separator_item="workspace.$monitor.$ws.separator"
  local trailing_item="workspace.$monitor.$ws.trailing"
  local workspace_members
  local window_item
  local slot
  local cmd

  workspace_members=("$item" "$separator_item")

  cmd=("$SKETCHYBAR_BIN"
    --add item "$item" left
    --set "$item"
    drawing=off
    display="$display"
    width="$WORKSPACE_ITEM_WIDTH"
    icon="$ws"
    icon.font="SF Pro:Semibold:14.0"
    icon.color="$WORKSPACE_INACTIVE_COLOR"
    icon.highlight_color=0xffffffff
    icon.padding_left=5
    icon.padding_right=4
    label=""
    label.font="SF Pro:Semibold:13.0"
    label.color="$WORKSPACE_INACTIVE_COLOR"
    label.highlight_color=0xffffffff
    label.padding_left=4
    label.padding_right=8
    label.y_offset="$SEPARATOR_Y_OFFSET"
    label.drawing=off
    background.drawing=off
    padding_left="$WORKSPACE_ITEM_PADDING_LEFT"
    padding_right="$WORKSPACE_ITEM_PADDING_RIGHT"
    click_script="aerospace workspace $ws"
    --add item "$separator_item" left
    --set "$separator_item"
    drawing=off
    display="$display"
    width="$SEPARATOR_ITEM_WIDTH"
    icon="━"
    icon.font="SF Pro:Bold:16.0"
    icon.color="$WORKSPACE_INACTIVE_COLOR"
    icon.highlight_color=0xffffffff
    icon.padding_left=2
    icon.padding_right=0
    label.drawing=off
    background.drawing=off
    padding_left="$SEPARATOR_ITEM_PADDING_LEFT"
    padding_right="$SEPARATOR_ITEM_PADDING_RIGHT"
  )

  for (( slot = 1; slot <= MAX_WINDOWS_PER_WORKSPACE; slot++ )); do
    window_item="workspace.$monitor.$ws.window.$slot"
    workspace_members+=("$window_item")

    cmd+=(
      --add item "$window_item" left
      --set "$window_item"
      drawing=off
      display="$display"
      width="$WINDOW_ITEM_WIDTH"
      icon=""
      icon.font="sketchybar-app-font:Regular:15.0"
      icon.color="$WORKSPACE_INACTIVE_COLOR"
      icon.padding_left=2
      icon.padding_right=2
      icon.y_offset=1
      label.drawing=off
      background.drawing=off
      padding_left="$WINDOW_ITEM_PADDING_LEFT"
      padding_right="$WINDOW_ITEM_PADDING_RIGHT"
    )
  done

  workspace_members+=("$trailing_item")

  cmd+=(
    --add item "$trailing_item" left
    --set "$trailing_item"
    drawing=off
    display="$display"
    width="$WORKSPACE_TRAILING_ITEM_WIDTH"
    icon.drawing=off
    label.drawing=off
    background.drawing=off
    padding_left=0
    padding_right=0
    --add bracket "group.workspace.$monitor.$ws" "${workspace_members[@]}"
    --set "group.workspace.$monitor.$ws"
    drawing=off
    display="$display"
    background.drawing=on
    background.color="$WORKSPACE_INACTIVE_BG"
    background.height=25
    background.corner_radius=14
  )

  "${cmd[@]}"
}

add_monitor_workspace_group() {
  local monitor="$1"
  local display="$2"
  shift 2
  local workspace_members=("$@")

  [[ ${#workspace_members[@]} -gt 0 ]] || return 0

  sb --add bracket "group.workspaces.$monitor" \
    "${workspace_members[@]}" \
    --set "group.workspaces.$monitor" \
    drawing=off \
    display="$display" \
    background.drawing=on \
    background.color="$PILL_BG" \
    background.height="$PILL_HEIGHT" \
    background.corner_radius="$PILL_RADIUS" \
    background.border_width="$PILL_BORDER_WIDTH" \
    background.border_color="$PILL_BORDER" \
    background.padding_left=4 \
    background.padding_right=4 \
    blur_radius=50
}

create_workspace_items() {
  local topology="$1"
  local workspaces="$2"
  local monitor display direct appkit name scale group ws slot
  local workspace_members
  local item separator_item trailing_item window_item

  while IFS='|' read -r monitor display direct appkit name scale group; do
    [[ -n "$monitor" ]] || continue

    workspace_members=()
    for ws in $workspaces; do
      item="workspace.$monitor.$ws"
      separator_item="workspace.$monitor.$ws.separator"
      trailing_item="workspace.$monitor.$ws.trailing"

      add_workspace_cluster "$monitor" "$display" "$ws"

      workspace_members+=("$item" "$separator_item")
      for (( slot = 1; slot <= MAX_WINDOWS_PER_WORKSPACE; slot++ )); do
        window_item="workspace.$monitor.$ws.window.$slot"
        workspace_members+=("$window_item")
      done
      workspace_members+=("$trailing_item")
    done

    add_monitor_workspace_group "$monitor" "$display" "${workspace_members[@]}"
  done <<< "$topology"
}

create_workspace_observer() {
  sb --add event aerospace_workspace_change \
    --add event aerospace_window_focus_change \
    --add event aerospace_workspace_refresh

  sb --add item workspace.observer left \
    --set workspace.observer \
    drawing=off \
    update_freq=0 \
    script="$RENDER_DIR/workspaces.sh" \
    --subscribe workspace.observer \
    aerospace_workspace_change \
    aerospace_window_focus_change \
    aerospace_workspace_refresh \
    display_change \
    system_woke
}
