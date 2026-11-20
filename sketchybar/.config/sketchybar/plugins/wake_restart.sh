#!/usr/bin/env bash

# Restarts SketchyBar once after a wake, because SketchyBar 2.24.1 rebuilds every
# item window several times on wake and leaves the old ones on screen
# (FelixKratz/SketchyBar#866).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${CONFIG_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# shellcheck source=/dev/null
source "$CONFIG_DIR/lib/runtime.sh"

[[ "${SENDER:-}" == "system_woke" ]] || exit 0

LAST_RESTART_FILE="$STATE_PREFIX-wake-restart-last"
RESTART_DELAY_SECONDS=10
MIN_RESTART_INTERVAL_SECONDS=60

# Let the wake's display changes settle first.
sleep "$RESTART_DELAY_SECONDS"

now="$(date +%s)"
last="$(cat "$LAST_RESTART_FILE" 2>/dev/null || printf '0')"
if (( now - last < MIN_RESTART_INTERVAL_SECONDS )); then
  log_msg "wake-restart" "skip last_restart=$((now - last))s_ago"
  exit 0
fi

printf '%s\n' "$now" > "$LAST_RESTART_FILE"
log_msg "wake-restart" "restart"
# Stopping the job also kills the other wake events' scripts that are still waiting.
launchctl kickstart -k "gui/$(id -u)/org.nixos.sketchybar"
