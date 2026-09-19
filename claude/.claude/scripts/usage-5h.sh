#!/bin/bash
# Prints "<5-hour usage percent> <window reset as epoch seconds>" for the claude.ai
# account and writes the same line to ~/.cache/dotfiles/claude/usage-5h. Reads
# https://api.anthropic.com/api/oauth/usage (undocumented, the same data /usage shows)
# with the OAuth token from the macOS Keychain, or from ~/.claude/.credentials.json
# on Linux. Exits 1 when usage cannot be read.
token=$( { security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null || cat "$HOME/.claude/.credentials.json" 2>/dev/null; } | jq -r '.claudeAiOauth.accessToken // empty')
[ -n "$token" ] || exit 1
out=$(curl -sf --max-time 5 https://api.anthropic.com/api/oauth/usage \
  -H "Authorization: Bearer $token" -H "anthropic-beta: oauth-2025-04-20" \
  | jq -r '"\(.five_hour.utilization | floor) \(.five_hour.resets_at | sub("\\.[0-9]+";"") | sub("\\+00:00$";"Z") | fromdate)"' 2>/dev/null)
[ -n "$out" ] || exit 1
cache="$HOME/.cache/dotfiles/claude/usage-5h"
mkdir -p "${cache%/*}" && printf '%s\n' "$out" > "$cache"
echo "$out"
