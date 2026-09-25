---
description: Set persistent mode. A cron job checks 5-hour usage every 5 minutes in the main chat; at 95% Claude saves every agent's state, waits for the reset, and resumes.
---
You are setting persistent mode for this session.

1. Create the flag, which makes the statusline show "📌 Persistent!":

   mkdir -p ~/.cache/dotfiles/claude/persistent && touch ~/.cache/dotfiles/claude/persistent/${CLAUDE_SESSION_ID}

2. Create the usage check with the CronCreate tool: cron `2-59/5 * * * *`, recurring, not durable, with exactly this prompt:

   Persistent-mode usage check. Run `~/.claude/scripts/usage-5h.sh` with `dangerouslyDisableSandbox` set to true; it prints "<percent> <reset epoch>" and refreshes the cache that the status line reads. Reply with one line giving the 5-hour usage percent and the reset time in local time, and do nothing else, unless the percent is 95 or more: then read ~/.claude/scripts/persistent-watch.md and follow it.

   The job fires only while the main chat is idle, which is when a long-running workflow needs it, and each firing re-renders the status line. It expires after 7 days; run this command again for a longer session.

3. Confirm in one line that persistent mode is on, then continue with whatever you were doing.

If the argument is `off`: find the usage-check job with CronList, delete it with CronDelete, run `rip ~/.cache/dotfiles/claude/persistent/${CLAUDE_SESSION_ID}`, and confirm that persistent mode is off.

Argument: $ARGUMENTS
