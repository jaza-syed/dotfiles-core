#!/bin/sh
# Link the selected mounted account's My Drive without storing its identity.
set -eu

if [ "$#" -ne 0 ]; then
    echo "Usage: ./scripts/link_google_drive.sh (selects from mounted Google Drive accounts)" >&2
    exit 2
fi

link_google_drive() {
    cloud_storage=$1
    destination=$2
    set --
    for account in "$cloud_storage"/GoogleDrive-*; do
        [ -d "$account/My Drive" ] || continue
        set -- "$@" "$account/My Drive"
    done
    if [ "$#" -eq 0 ]; then
        echo "No mounted Google Drive accounts found. Sign in to Google Drive first." >&2
        exit 1
    fi

    if [ "$#" -gt 1 ]; then
        index=1
        for account; do
            printf '%s) %s\n' "$index" "$account" >/dev/tty
            index=$((index + 1))
        done
        printf 'Account number for ~/drive-jaza: ' >/dev/tty
        read -r selection </dev/tty
        case "$selection" in
        '' | *[!0-9]*)
            echo "Invalid account number" >&2
            exit 1
            ;;
        esac
        if [ "$selection" -lt 1 ] || [ "$selection" -gt "$#" ]; then
            echo "Invalid account number" >&2
            exit 1
        fi
        shift "$((selection - 1))"
    fi

    if [ -L "$destination" ] && [ "$(readlink "$destination")" = "$1" ]; then
        echo "~/drive-jaza already links to the selected account."
        exit 0
    fi
    if [ -e "$destination" ] || [ -L "$destination" ]; then
        echo "Refusing to replace $destination. Move the existing file or link aside first." >&2
        exit 1
    fi
    ln -s "$1" "$destination"
    echo "Created ~/drive-jaza."
}

link_google_drive "$HOME/Library/CloudStorage" "$HOME/drive-jaza"
