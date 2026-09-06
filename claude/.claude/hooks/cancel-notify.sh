#!/bin/bash
# Cancel any pending delayed notification. Wired to UserPromptSubmit and
# PreToolUse so user activity within 10s suppresses the banner.
PID_FILE="$HOME/.claude/hooks/.notify.pid"
[ -f "$PID_FILE" ] && kill "$(cat "$PID_FILE")" 2>/dev/null
rm -f "$PID_FILE"
exit 0
