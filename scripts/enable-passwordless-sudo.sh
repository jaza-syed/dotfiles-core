#!/bin/sh

set -e

TARGET_USER="${1:-$(id -un)}"
SUDOERS_DIR="/private/etc/sudoers.d"
SUDOERS_FILE="$SUDOERS_DIR/$TARGET_USER"
TMP_FILE="$(mktemp)"

cleanup() {
    rm -f "$TMP_FILE"
}

trap cleanup EXIT INT TERM

cat > "$TMP_FILE" <<EOF
$TARGET_USER ALL = (ALL) NOPASSWD: ALL
EOF

echo "About to install passwordless sudo for user: $TARGET_USER"
echo "Target file: $SUDOERS_FILE"
printf 'Continue? [y/N] '
read -r answer

case "$answer" in
    y|Y|yes|YES)
        ;;
    *)
        echo "Aborted."
        exit 1
        ;;
esac

sudo mkdir -p "$SUDOERS_DIR"
sudo install -m 0440 "$TMP_FILE" "$SUDOERS_FILE"

if sudo visudo -c -f "$SUDOERS_FILE"; then
    echo "Installed and validated: $SUDOERS_FILE"
else
    echo "Validation failed; removing $SUDOERS_FILE" >&2
    sudo rm -f "$SUDOERS_FILE"
    exit 1
fi
