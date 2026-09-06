#!/usr/bin/env bash

# Shared configuration constants. This file is intended to be sourced.

# Item/group colors.
PILL_BG=0x40000000
PILL_BORDER=0x30000000
PILL_HEIGHT=26
PILL_RADIUS=14
PILL_BORDER_WIDTH=0

WORKSPACE_INACTIVE_COLOR=0x70ffffff
WORKSPACE_INACTIVE_BG=0x18000000
CHIP_ACTIVE_BG=0x50000000
CHIP_INACTIVE_BG=0x18000000
WINDOW_INACTIVE_COLOR=0x70ffffff
WINDOW_FOCUSED_COLOR=0xffffffff
SEPARATOR_COLOR=0xffffffff

BAR_BG=0x66323232
BAR_BORDER=0x24ffffff

DEFAULT_WORKSPACES=(A B C D E 1 2 3 4 5)
MAX_WINDOWS_PER_WORKSPACE=16

# The second bar instance is a geometry workaround: SketchyBar bar-level
# offsets are global per instance, while notched and non-notched displays need
# different offsets in the vertical setup. The historical process name is kept
# to avoid changing launch/state assumptions.
OFFSET_BAR_NAME="${OFFSET_BAR_NAME:-sketchybar-nonretina}"
OFFSET_BAR_BIN="${OFFSET_BAR_BIN:-/tmp/$OFFSET_BAR_NAME}"
OFFSET_BAR_Y_OFFSET=28

DEFAULT_BAR_VARIANT=vertical
BAR_VARIANT="${BAR_VARIANT:-$DEFAULT_BAR_VARIANT}"

normalize_bar_variant() {
  case "$BAR_VARIANT" in
    vertical|left) BAR_VARIANT=vertical ;;
    *) BAR_VARIANT=horizontal ;;
  esac
}

apply_bar_variant_settings() {
  normalize_bar_variant

  if [[ "$BAR_VARIANT" == "vertical" ]]; then
    BAR_POSITION=left
    BAR_HEIGHT=30
    BAR_MARGIN=4
    BAR_X_OFFSET=0
    BAR_Y_OFFSET="${BAR_Y_OFFSET:-0}"
    SEPARATOR_Y_OFFSET=0
    WORKSPACE_ITEM_WIDTH=18
    WORKSPACE_ITEM_PADDING_LEFT=0
    WORKSPACE_ITEM_PADDING_RIGHT=0
    WINDOW_ITEM_WIDTH=20
    WINDOW_ITEM_PADDING_LEFT=0
    WINDOW_ITEM_PADDING_RIGHT=0
    SEPARATOR_ITEM_WIDTH=9
    SEPARATOR_ITEM_PADDING_LEFT=0
    SEPARATOR_ITEM_PADDING_RIGHT=0
    WORKSPACE_TRAILING_ITEM_WIDTH=7
  else
    BAR_POSITION=bottom
    BAR_HEIGHT=40
    BAR_MARGIN=4
    BAR_X_OFFSET=0
    BAR_Y_OFFSET="${BAR_Y_OFFSET:-3}"
    SEPARATOR_Y_OFFSET=1
    WORKSPACE_ITEM_WIDTH=-1
    WORKSPACE_ITEM_PADDING_LEFT=2
    WORKSPACE_ITEM_PADDING_RIGHT=0
    WINDOW_ITEM_WIDTH=-1
    WINDOW_ITEM_PADDING_LEFT=0
    WINDOW_ITEM_PADDING_RIGHT=0
    SEPARATOR_ITEM_WIDTH=-1
    SEPARATOR_ITEM_PADDING_LEFT=0
    SEPARATOR_ITEM_PADDING_RIGHT=0
    WORKSPACE_TRAILING_ITEM_WIDTH=0
  fi
}

default_workspaces_string() {
  printf '%s\n' "${DEFAULT_WORKSPACES[@]}"
}
