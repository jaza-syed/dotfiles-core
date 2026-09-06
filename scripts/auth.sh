#!/bin/sh

set -e

SSH_KEY_PATH="$HOME/.ssh/id_ed25519"
SSH_KEY_COMMENT="${DOTFILES_SSH_KEY_COMMENT:-$(git config --global --includes user.email 2>/dev/null || true)}"

if [ -z "$SSH_KEY_COMMENT" ]; then
    SSH_KEY_COMMENT="dotfiles"
fi

ensure_ssh_key() {
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    if [ ! -f "$SSH_KEY_PATH" ]; then
        ssh-keygen -t ed25519 -C "$SSH_KEY_COMMENT" -f "$SSH_KEY_PATH"
    fi
}

add_ssh_key() {
    if [ "$(uname -s)" = "Darwin" ]; then
        ssh-add --apple-use-keychain "$SSH_KEY_PATH" >/dev/null 2>&1 || true
    else
        ssh-add "$SSH_KEY_PATH" >/dev/null 2>&1 || true
    fi
}

auth_github() {
    if ! command -v gh >/dev/null 2>&1; then
        echo "gh is not installed. Run the phase 1 base switch first (see install.md)." >&2
        exit 1
    fi

    ensure_ssh_key

    if ! env -u GH_TOKEN -u GITHUB_TOKEN gh auth status --hostname github.com >/dev/null 2>&1; then
        env -u GH_TOKEN -u GITHUB_TOKEN gh auth login --hostname github.com --web --git-protocol ssh
    fi

    # Preserve an existing HTTPS login. Only the interactive login above may
    # choose SSH, because it also offers to register the selected public key.
    add_ssh_key
}

auth_1password() {
    if ! command -v op >/dev/null 2>&1; then
        echo "op is not installed. Run the phase 1 base switch first (see install.md)." >&2
        exit 1
    fi

    if op whoami >/dev/null 2>&1; then
        return
    fi

    if ! op signin; then
        op account add
        eval "$(op signin)"
    fi
}

auth_github
auth_1password
