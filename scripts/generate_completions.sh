#!/bin/sh
# Generate local shell completion artifacts for selected CLI tools.
#
# Generated files are machine-local cache artifacts and are not committed.
# Override the output root with DOTFILES_COMPLETIONS_DIR if needed.

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)
CACHE_ROOT=${DOTFILES_COMPLETIONS_DIR:-$HOME/.cache/dotfiles/completions}

cd "$REPO_DIR"

if [ -z "$CACHE_ROOT" ] || [ "$CACHE_ROOT" = "/" ]; then
    echo "generate_completions.sh: refusing unsafe completion cache path: $CACHE_ROOT" >&2
    exit 1
fi

load_homebrew() {
    if command -v brew >/dev/null 2>&1; then
        eval "$(brew shellenv)"
        return
    fi

    for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [ -x "$brew_bin" ]; then
            eval "$("$brew_bin" shellenv)"
            return
        fi
    done
}

run_tool() {
    if command -v mise >/dev/null 2>&1; then
        mise exec -- "$@"
    else
        "$@"
    fi
}

have_tool() {
    if command -v "$1" >/dev/null 2>&1; then
        return 0
    fi

    if command -v mise >/dev/null 2>&1; then
        mise exec -- sh -c 'command -v "$1" >/dev/null 2>&1' sh "$1" 2>/dev/null
        return $?
    fi

    return 1
}

generate_completion() {
    gen_shell=$1
    gen_tool=$2
    gen_file=$3
    shift 3

    if ! have_tool "$gen_tool"; then
        printf 'skip %-4s %-12s not installed\n' "$gen_shell" "$gen_tool"
        return 0
    fi

    gen_out="$TMP_ROOT/$gen_shell/$gen_file"
    if run_tool "$@" >"$gen_out"; then
        if [ -s "$gen_out" ]; then
            GENERATED_COUNT=$((GENERATED_COUNT + 1))
            printf 'generated %s/%s\n' "$gen_shell" "$gen_file"
        else
            rm -f "$gen_out"
            printf 'skip %-4s %-12s generated empty output\n' "$gen_shell" "$gen_tool" >&2
        fi
    else
        rm -f "$gen_out"
        printf 'warning: failed to generate %s/%s\n' "$gen_shell" "$gen_file" >&2
    fi
}

gen_zsh() {
    generate_completion zsh "$@"
}

gen_bash() {
    generate_completion bash "$@"
}

cleanup() {
    if [ -n "${TMP_ROOT:-}" ]; then
        rm -rf "$TMP_ROOT"
    fi
}

load_homebrew

CACHE_PARENT=$(dirname "$CACHE_ROOT")
CACHE_NAME=$(basename "$CACHE_ROOT")
TMP_ROOT="$CACHE_PARENT/.$CACHE_NAME.tmp.$$"
GENERATED_COUNT=0

trap cleanup EXIT HUP INT TERM
rm -rf "$TMP_ROOT"
mkdir -p "$TMP_ROOT/zsh" "$TMP_ROOT/bash"

# Core shell/dev tools.
gen_zsh mise _mise mise completion zsh
gen_bash mise mise.bash mise completion bash

gen_zsh atuin _atuin atuin gen-completions --shell zsh
gen_bash atuin atuin.bash atuin gen-completions --shell bash

gen_zsh starship _starship starship completions zsh
gen_bash starship starship.bash starship completions bash

gen_zsh gh _gh gh completion -s zsh
gen_bash gh gh.bash gh completion -s bash

gen_zsh glab _glab glab completion -s zsh
gen_bash glab glab.bash glab completion -s bash

gen_zsh just _just env JUST_COMPLETE=zsh just
gen_bash just just.bash env JUST_COMPLETE=bash just

gen_zsh uv _uv uv generate-shell-completion zsh
gen_bash uv uv.bash uv generate-shell-completion bash

gen_zsh uvx _uvx uvx --generate-shell-completion zsh
gen_bash uvx uvx.bash uvx --generate-shell-completion bash

gen_zsh pixi _pixi pixi completion --shell zsh
gen_bash pixi pixi.bash pixi completion --shell bash

gen_zsh bun _bun bun completions

gen_zsh zellij _zellij zellij setup --generate-completion zsh
gen_bash zellij zellij.bash zellij setup --generate-completion bash

# Search/listing/process tools.
gen_zsh rg _rg rg --generate complete-zsh
gen_bash rg rg.bash rg --generate complete-bash

gen_zsh fd _fd fd --gen-completions zsh
gen_bash fd fd.bash fd --gen-completions bash

gen_zsh bat _bat bat --completion zsh
gen_bash bat bat.bash bat --completion bash

gen_zsh procs _procs procs --gen-completion-out zsh
gen_bash procs procs.bash procs --gen-completion-out bash

# DevOps / infra tools.
gen_zsh kubectl _kubectl kubectl completion zsh
gen_bash kubectl kubectl.bash kubectl completion bash

gen_zsh k9s _k9s k9s completion zsh
gen_bash k9s k9s.bash k9s completion bash

gen_zsh rclone _rclone rclone completion zsh -
gen_bash rclone rclone.bash rclone completion bash -

gen_zsh docker _docker docker completion zsh
gen_bash docker docker.bash docker completion bash

# Language/runtime tools.
gen_zsh rustup _rustup rustup completions zsh rustup
gen_bash rustup rustup.bash rustup completions bash rustup

gen_zsh rustup _cargo rustup completions zsh cargo
gen_bash rustup cargo.bash rustup completions bash cargo

gen_zsh ghcup _ghcup ghcup --zsh-completion-script ghcup
gen_bash ghcup ghcup.bash ghcup --bash-completion-script ghcup

gen_bash node node.bash node --completion-bash

rm -rf "$CACHE_ROOT"
mv "$TMP_ROOT" "$CACHE_ROOT"
TMP_ROOT=
trap - EXIT HUP INT TERM

printf 'Generated %s completion files in %s\n' "$GENERATED_COUNT" "$CACHE_ROOT"
