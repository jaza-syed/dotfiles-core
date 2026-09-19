#!/bin/bash
# PostToolUse hook: in a persistent top-level session whose 5-hour usage is at or over
# PERSIST_ALERT percent (default 90), give Claude the persist procedure once per usage
# window and a reminder after every later tool call.
input=$(cat)
[ -n "$(jq -r '.agent_id // empty' <<<"$input")" ] && exit 0
flag="$HOME/.cache/dotfiles/claude/persistent/$(jq -r '.session_id // empty' <<<"$input")"
[ -f "$flag" ] || exit 0
cache="$HOME/.cache/dotfiles/claude/usage-5h"
# Refresh the cache in the background once it is over 2 minutes old, so the hook never waits on the network.
[ -n "$(find "$cache" -mmin -2 2>/dev/null)" ] || ("$HOME/.claude/scripts/usage-5h.sh" >/dev/null 2>&1 &)
[ -r "$cache" ] || exit 0
read -r pct resets < "$cache"
pct=${pct%%.*}; resets=${resets%%.*}
[ "$pct" -ge "${PERSIST_ALERT:-90}" ] 2>/dev/null || exit 0
[ "$resets" -gt "$(date +%s)" ] 2>/dev/null || exit 0
msg="5-hour usage is at ${pct}% and this session is persistent."
# The flag holds the reset time of the window whose procedure Claude has been given.
if [ "$(cat "$flag")" = "$resets" ]; then
  jq -cn --arg ctx "$msg Continue the persist procedure in ~/.claude/hooks/persistent-alert.md and start no other work." \
    '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$ctx}}'
else
  echo "$resets" > "$flag"
  jq -cn --arg msg "$msg" --rawfile body "${0%.sh}.md" --arg id "${flag##*/}" \
    '{systemMessage:$msg, hookSpecificOutput:{hookEventName:"PostToolUse", additionalContext:($msg + " Do the following now, before any other work.\n\n" + ($body | gsub("\\$\\{CLAUDE_SESSION_ID\\}"; $id)))}}'
fi
