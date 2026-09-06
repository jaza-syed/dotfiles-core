#!/usr/bin/env bash

# Static horizontal-status items. Intended to be sourced.

create_left_spacer() {
  sb --add item spacer.left left \
    --set spacer.left width=10 icon.drawing=off label.drawing=off
}

create_focused_window_item() {
  sb --add item focused_window center \
    --set focused_window \
    drawing=off \
    icon.drawing=off \
    label="" \
    label.padding_left=16 \
    label.padding_right=16 \
    update_freq=2 \
    script="$PLUGIN_DIR/focused_window.sh" \
    background.color="$PILL_BG" \
    background.height="$PILL_HEIGHT" \
    background.corner_radius="$PILL_RADIUS" \
    background.border_width="$PILL_BORDER_WIDTH" \
    background.border_color="$PILL_BORDER" \
    blur_radius=50 \
    padding_left=8 \
    padding_right=8

  sb --subscribe focused_window \
    front_app_switched \
    system_woke
}

create_status_items() {
  sb --add item spacer.right right \
    --set spacer.right \
    width=0 \
    icon.drawing=off \
    label.drawing=off

  sb --add item clock right \
    --set clock \
    update_freq=10 \
    icon="" \
    icon.padding_left=0 \
    icon.padding_right=0 \
    label.padding_left=8 \
    label.padding_right=10 \
    script="$PLUGIN_DIR/clock.sh"

  sb --add item battery right \
    --set battery \
    update_freq=15 \
    icon.padding_left=8 \
    icon.padding_right=4 \
    label.padding_left=1 \
    label.padding_right=8 \
    script="$PLUGIN_DIR/battery.sh" \
    --subscribe battery system_woke power_source_change

  sb --add item volume right \
    --set volume \
    icon.padding_left=8 \
    icon.padding_right=4 \
    label.padding_left=1 \
    label.padding_right=8 \
    script="$PLUGIN_DIR/volume.sh" \
    --subscribe volume volume_change system_woke

  sb --add bracket group.status \
    volume \
    battery \
    clock \
    --set group.status \
    background.color="$PILL_BG" \
    background.height="$PILL_HEIGHT" \
    background.corner_radius="$PILL_RADIUS" \
    background.border_width="$PILL_BORDER_WIDTH" \
    background.border_color="$PILL_BORDER" \
    background.padding_left=4 \
    background.padding_right=4 \
    blur_radius=50
}
