#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${CONFIG_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
# shellcheck source=/dev/null
source "$CONFIG_DIR/lib/runtime.sh"

app_running() {
  local app_name="$1"
  local result

  result="$(osascript -e "tell application \"System Events\" to exists application process \"$app_name\"" 2>/dev/null || true)"
  [[ "$result" == "true" ]]
}

ITEMS=(
  "utility_onepassword|1Password"
  "utility_cold_turkey|Cold Turkey Blocker"
  "utility_lulu|LuLu"
  "utility_scroll_reverser|Scroll Reverser"
  "utility_flux|Flux"
)

visible_count=0
cmd=("$SKETCHYBAR_BIN")

for entry in "${ITEMS[@]}"; do
  IFS='|' read -r item_name app_name <<< "$entry"

  if app_running "$app_name"; then
    visible_count=$((visible_count + 1))
    cmd+=(--set "$item_name" drawing=on)
  else
    cmd+=(--set "$item_name" drawing=off)
  fi
done

if (( visible_count > 0 )); then
  cmd+=(--set utility_gap width=8)
  cmd+=(--set group_utilities drawing=on)
else
  cmd+=(--set utility_gap width=0)
  cmd+=(--set group_utilities drawing=off)
fi

"${cmd[@]}"
