#!/bin/sh
# Isolated checks: no authentication, installs, or changes to the real home.
set -eu
REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT

# Authentication must preserve an existing login's protocol, or use the
# interactive SSH registration flow when no stored login exists.
eval "$(sed '/^auth_github$/d; /^auth_1password$/d' "$REPO_DIR/scripts/auth.sh")"
ensure_ssh_key() { :; }
add_ssh_key() { :; }
export TEST_AUTH_LOG="$fixture/auth.log"
export TEST_GH_AUTHENTICATED=1
PATH="$REPO_DIR/tests/fixtures:$PATH" auth_github
[ "$(wc -l <"$TEST_AUTH_LOG" | tr -d ' ')" = 1 ]
export TEST_GH_AUTHENTICATED=0
PATH="$REPO_DIR/tests/fixtures:$PATH" auth_github
rg -q '^auth login --hostname github.com --web --git-protocol ssh$' "$TEST_AUTH_LOG"

echo "Setup regression checks passed"
