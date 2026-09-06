#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${CONFIG_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
# shellcheck source=/dev/null
source "$CONFIG_DIR/lib/runtime.sh"

PERCENTAGE="$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)"
CHARGING="$(pmset -g batt | grep 'AC Power')"
LOW_POWER_MODE="$(pmset -g custom | awk '/lowpowermode/{print $2; exit}')"
NORMAL_COLOR="0xffffffff"
LOW_POWER_COLOR="0xffffd166"

if [[ -z "$PERCENTAGE" ]]; then
  exit 0
fi

case "${PERCENTAGE}" in
  9[0-9]|100) ICON="" ;;
  [6-8][0-9]) ICON="" ;;
  [3-5][0-9]) ICON="" ;;
  [1-2][0-9]) ICON="" ;;
  *) ICON="" ;;
esac

if [[ -n "$CHARGING" ]]; then
  ICON=""
fi

COLOR="$NORMAL_COLOR"
if [[ "$LOW_POWER_MODE" == "1" ]]; then
  COLOR="$LOW_POWER_COLOR"
fi

sb --set "$NAME" \
  icon="$ICON" \
  label="${PERCENTAGE}%" \
  icon.color="$COLOR" \
  label.color="$COLOR"
