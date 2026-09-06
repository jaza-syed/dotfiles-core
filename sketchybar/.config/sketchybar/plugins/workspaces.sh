#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${CONFIG_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"

exec "$CONFIG_DIR/render/workspaces.sh" "$@"
