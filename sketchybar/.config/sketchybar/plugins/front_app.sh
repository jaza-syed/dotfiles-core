#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${CONFIG_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
# shellcheck source=/dev/null
source "$CONFIG_DIR/lib/runtime.sh"

if [[ "${SENDER:-}" == "front_app_switched" ]]; then
  sb --set "$NAME" label="${INFO:-}"
fi
