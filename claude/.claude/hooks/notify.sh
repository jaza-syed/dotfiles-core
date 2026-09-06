#!/bin/bash
# Notification hook: schedule a macOS notification 10s after Claude requests
# input. Cancelled by ~/.claude/hooks/cancel-notify.sh if the user responds.

payload=$(cat)
msg=$(jq -r '.message // "Claude needs your input"' <<<"$payload" 2>/dev/null)
[ -z "$msg" ] && msg="Claude needs your input"

PID_FILE="$HOME/.claude/hooks/.notify.pid"
[ -f "$PID_FILE" ] && kill "$(cat "$PID_FILE")" 2>/dev/null
rm -f "$PID_FILE"

(
  sleep 10
  /opt/homebrew/bin/terminal-notifier \
    -title "Claude Code" \
    -message "$msg" \
    -sound Glass \
    >/dev/null 2>&1
  rm -f "$PID_FILE"
) >/dev/null 2>&1 &
echo $! > "$PID_FILE"
disown 2>/dev/null || true
