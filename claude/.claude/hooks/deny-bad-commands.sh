#!/bin/bash
# PreToolUse hook: deny a Bash call that breaks the command-running rules in CLAUDE.md.
input=$(cat)
cmd=$(jq -r '.tool_input.command // ""' <<<"$input")
background=$(jq -r '.tool_input.run_in_background // false' <<<"$input")

deny() {
  jq -cn --arg reason "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
  exit 0
}

has() { grep -qE -e "$1" <<<"$cmd"; }

if has '\|&?[[:space:]]*tee([[:space:]]|$)'; then
  if [[ $background == true ]]; then
    deny 'Run a backgrounded command bare, without tee. The harness writes its stdout and stderr to its own output file and reports the exit code in the completion notification.'
  fi
  deny 'A foreground command must redirect rather than pipe through tee: cmd > "$log" 2>&1; echo "exit=$?"; tail -20 "$log". On a non-zero exit the harness keeps only the start of the stream and drops the end.'
fi

if has '(^|[;&|(]|&&|\|\|)[[:space:]]*rg[[:space:]]([^|;&]*[[:space:]])?-[A-Za-z]*r[A-Za-z]*([[:space:]]|$)'; then
  deny 'In rg, -r means --replace, so the args shift by one and you get an empty result that reads as "no matches" with no error. rg recurses by default, so drop the flag.'
fi

exit 0
