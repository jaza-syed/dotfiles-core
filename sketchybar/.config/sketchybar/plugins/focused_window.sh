#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${CONFIG_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
# shellcheck source=/dev/null
source "$CONFIG_DIR/lib/runtime.sh"

MAX_CHARS=40

normalize_label() {
  local value

  value="$(printf '%s' "$1" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"
  if [[ "$value" == "missing value" ]]; then
    value=""
  fi

  printf '%s\n' "$value"
}

label_text() {
  local raw app_name window_name

  raw="$(
    osascript 2>/dev/null <<'APPLESCRIPT' || true
tell application "System Events"
  set frontApp to first application process whose frontmost is true
  set appName to name of frontApp

  try
    set windowName to name of front window of frontApp
  on error
    set windowName to ""
  end try

  return appName & linefeed & windowName
end tell
APPLESCRIPT
  )"

  app_name="${raw%%$'\n'*}"
  if [[ "$raw" == *$'\n'* ]]; then
    window_name="${raw#*$'\n'}"
  else
    window_name=""
  fi

  app_name="$(normalize_label "$app_name")"
  window_name="$(normalize_label "$window_name")"

  printf '%s\n' "$app_name"
}

title="$(label_text)"

if [[ -n "${INFO:-}" && "$INFO" != "$title" && -z "${title:-}" ]]; then
  title="$(normalize_label "$INFO")"
fi

if [[ -n "$title" && ${#title} -gt $MAX_CHARS ]]; then
  title="${title:0:$((MAX_CHARS - 3))}..."
fi

if [[ -z "$title" ]]; then
  sb --set "$NAME" drawing=off label="" label.drawing=off
  exit 0
fi

sb --set "$NAME" \
  drawing=on \
  label="$title" \
  label.drawing=on
