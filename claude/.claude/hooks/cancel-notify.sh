#!/bin/bash
# UserPromptSubmit hook: cancel the pending delayed notification.
PID_FILE="$HOME/.claude/hooks/.notify.pid"
[ -f "$PID_FILE" ] && kill "$(cat "$PID_FILE")" 2>/dev/null
rm -f "$PID_FILE"

# Clear the Rex status that Claude sets while it waits for an answer
if [ "$TERM_PROGRAM" = rex ]; then
  p=$PPID
  while [ "$p" -gt 1 ]; do
    t=$(ps -o tty= -p "$p" | tr -d ' ')
    if [ -n "$t" ] && [ "$t" != '??' ]; then
      printf '\e]7501;state=clear:id=claude\e\\' > "/dev/$t"
      break
    fi
    p=$(ps -o ppid= -p "$p" | tr -d ' ')
  done
fi
exit 0
