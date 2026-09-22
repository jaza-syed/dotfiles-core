#!/bin/bash
# Prints "<5-hour usage percent> <window reset as epoch seconds>" for the claude.ai
# account and caches the same line in ~/.cache/dotfiles/claude/usage-5h. Reads
# https://api.anthropic.com/api/oauth/usage (undocumented, the same data /usage shows)
# with the OAuth token from the macOS Keychain, or from ~/.claude/.credentials.json on
# Linux.
#   exit 0  printed the reading
#   exit 1  no OAuth token, so a retry will not help
#   exit 2  the request failed; prints "http=<code> retry-after=<seconds>" on stderr
cache="$HOME/.cache/dotfiles/claude/usage-5h"
token=$( { security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null || cat "$HOME/.claude/.credentials.json" 2>/dev/null; } | jq -r '.claudeAiOauth.accessToken // empty')
[ -n "$token" ] || { echo "no oauth token" >&2; exit 1; }
hdrs=$(mktemp); body=$(mktemp); trap 'rm -f "$hdrs" "$body"' EXIT
code=$(curl -s --max-time 10 -o "$body" -D "$hdrs" -w '%{http_code}' \
  https://api.anthropic.com/api/oauth/usage \
  -H "Authorization: Bearer $token" -H "anthropic-beta: oauth-2025-04-20")
if [ "$code" != "200" ]; then
  retry=$(grep -i '^retry-after:' "$hdrs" | tail -1 | tr -d '\r' | awk '{print $2}')
  echo "http=${code:-000} retry-after=${retry:-unknown}" >&2
  exit 2
fi
out=$(jq -r '"\(.five_hour.utilization | floor) \(.five_hour.resets_at | sub("\\.[0-9]+";"") | sub("\\+00:00$";"Z") | fromdate)"' <"$body" 2>/dev/null)
[ -n "$out" ] || { echo "http=200 but the body did not parse" >&2; exit 2; }
mkdir -p "$(dirname "$cache")" && echo "$out" >"$cache"
echo "$out"
