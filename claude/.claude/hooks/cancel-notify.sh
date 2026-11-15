#!/bin/bash
# UserPromptSubmit hook: cancel the pending delayed notification.
PID_FILE="$HOME/.claude/hooks/.notify.pid"
[ -f "$PID_FILE" ] && kill "$(cat "$PID_FILE")" 2>/dev/null
rm -f "$PID_FILE"
exit 0
