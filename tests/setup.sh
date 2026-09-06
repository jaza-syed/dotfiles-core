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

# Load just the helper, supplying fixture paths instead of touching ~/drive-jaza.
eval "$(sed '/^link_google_drive "\$HOME/d' "$REPO_DIR/scripts/link_google_drive.sh")"
mkdir -p "$fixture/accounts"
if (link_google_drive "$fixture/accounts" "$fixture/link") 2>/dev/null; then
    echo "Missing accounts should fail" >&2
    exit 1
fi
mkdir -p "$fixture/accounts/GoogleDrive-test/My Drive"
(link_google_drive "$fixture/accounts" "$fixture/link")
[ "$(readlink "$fixture/link")" = "$fixture/accounts/GoogleDrive-test/My Drive" ]
(link_google_drive "$fixture/accounts" "$fixture/link")
mkdir "$fixture/existing"
if (link_google_drive "$fixture/accounts" "$fixture/existing") 2>/dev/null; then
    echo "Existing directory should be preserved" >&2
    exit 1
fi
ln -s "$fixture/missing" "$fixture/broken"
if (link_google_drive "$fixture/accounts" "$fixture/broken") 2>/dev/null; then
    echo "Existing broken symlink should be preserved" >&2
    exit 1
fi
[ "$(readlink "$fixture/broken")" = "$fixture/missing" ]

echo "Setup regression checks passed"
