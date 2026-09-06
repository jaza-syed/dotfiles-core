#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${CONFIG_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
# shellcheck source=/dev/null
source "$CONFIG_DIR/lib/runtime.sh"

# The volume_change event supplies $INFO with the current volume percentage.
if [[ "${SENDER:-}" == "volume_change" && -n "${INFO:-}" ]]; then
  VOLUME="$INFO"
else
  VOLUME="$(osascript -e 'output volume of (get volume settings)')"
fi

MUTED="$(osascript -e 'output muted of (get volume settings)')"

case "$VOLUME" in
  [6-9][0-9]|100) ICON="󰕾" ;;
  [3-5][0-9]) ICON="󰖀" ;;
  [1-9]|[1-2][0-9]) ICON="󰕿" ;;
  *) ICON="󰖁" ;;
esac

if [[ "$MUTED" == "true" || "$VOLUME" == "0" ]]; then
  ICON="󰖁"
fi

sb --set "$NAME" icon="$ICON" label="$VOLUME%"
