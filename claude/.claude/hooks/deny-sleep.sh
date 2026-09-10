#!/bin/bash
# PreToolUse hook: deny a Bash call that sleeps, so Claude waits for the task notification instead.
cmd=$(jq -r '.tool_input.command' 2>/dev/null)
if grep -qE '(^|[;&|(]|&&|\|\|)[[:space:]]*sleep([[:space:]]|$)' <<<"$cmd"; then
  printf '%s' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Never sleep to wait for a backgrounded command. Its task-completion notification arrives on its own, so read the output file when it does. Poll before then only to check whether a log has stopped growing, and make that a bare read with no sleep."}}'
fi
exit 0
