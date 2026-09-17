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

if [[ $background == true ]]; then
  if ! has '\|&?[[:space:]]*tee([[:space:]]|$)'; then
    deny 'A backgrounded command must pipe through tee so its log can be polled while it runs: cmd 2>&1 | tee "$log"; echo "exit=${pipestatus[1]}".'
  fi
  if has '\|&?[[:space:]]*tee[[:space:]]+[^|;&]*\|'; then
    deny 'The pipeline must end at tee. A filter after it buffers until the command exits, so nothing streams live and polling the log returns nothing. Trim the log in a follow-up command instead.'
  fi
  # nix and most build tools write their progress to stderr, not stdout.
  if ! has '(2>&1|\|&)'; then
    deny 'Redirect stderr into the log as well, with 2>&1 before the pipe. Most build tools write their progress to stderr, so a log without it records almost nothing.'
  fi
  if has '\|&?[[:space:]]*tee[^|;&]*\$TMPDIR'; then
    deny '$TMPDIR differs between invocations, so a log written there cannot be read back by a later command. Use the scratchpad directory from the system prompt.'
  fi
elif has '\|&?[[:space:]]*tee([[:space:]]|$)'; then
  deny 'A foreground command must redirect rather than pipe through tee: cmd > "$log" 2>&1; echo "exit=$?"; tail -20 "$log". On a non-zero exit the harness spends its character budget on the start of the stream and drops the end.'
fi

# pipefail turns the producer's SIGPIPE into exit 141, which reads as a failure.
if has '\|&?[[:space:]]*head([[:space:]]|$)' && ! has '(rg|fd|cat)[^|]*\|&?[[:space:]]*head([[:space:]]|$)'; then
  deny 'Piping into head makes the producer die of SIGPIPE, which pipefail reports as exit 141 rather than success. Use | tail, or pipe rg, fd or cat into head.'
fi

if has '(^|[;&|(]|&&|\|\|)[[:space:]]*rg([[:space:]]|$)'; then
  if ! has '--color[= ]never'; then
    deny 'rg must be passed --color never.'
  fi
  if has 'rg[[:space:]]([^|;&]*[[:space:]])?-[A-Za-z]*r[A-Za-z]*([[:space:]]|$)'; then
    deny 'In rg, -r means --replace, so the args shift by one and you get an empty result that reads as "no matches" with no error. rg recurses by default, so drop the flag.'
  fi
fi

exit 0
