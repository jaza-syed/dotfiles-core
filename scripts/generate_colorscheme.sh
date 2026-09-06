#!/bin/sh

set -e

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

if command -v luajit >/dev/null 2>&1; then
  exec "$(command -v luajit)" "$REPO_DIR/palettes/generate.lua" "$@"
fi

if command -v lua >/dev/null 2>&1; then
  exec "$(command -v lua)" "$REPO_DIR/palettes/generate.lua" "$@"
fi

echo "generate_colorscheme.sh: neither luajit nor lua is installed" >&2
exit 1
