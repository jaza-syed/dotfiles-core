---
description: Set persistent mode. A background watcher waits until 5-hour usage reaches 95%, then has Claude save every agent's state, wait for the reset, and resume.
---
You are setting persistent mode for this session.

1. Create the flag, which makes the statusline show "📌 Persistent!":

   mkdir -p ~/.cache/dotfiles/claude/persistent && touch ~/.cache/dotfiles/claude/persistent/${CLAUDE_SESSION_ID}

2. Start the watcher in the background, with `$log` in the scratchpad directory and `dangerouslyDisableSandbox` set to true:

   : >"$log" && ~/.claude/scripts/persistent-watch.sh ${CLAUDE_SESSION_ID} 2>&1 | tee "$log"

   The sandbox denies writes to the scratchpad directory, and `tee` keeps running when it cannot open its file, so the `: >"$log"` makes a bad log path fail before the watcher starts. If the command exits at once, read the error and fix the path rather than starting the watcher without a log.

   It makes no model calls and exits when 5-hour usage reaches 95%, printing the procedure: collect a STATE REPORT from every agent, write a handoff file under ~/.claude, wait in a background call until the window resets, then relaunch the agents from that file. When its completion notification arrives, read the log and follow it.

3. Confirm in one line that persistent mode is on, then continue with whatever you were doing.

If the argument is `off`: stop the watcher task, run `rip ~/.cache/dotfiles/claude/persistent/${CLAUDE_SESSION_ID}`, and confirm that persistent mode is off.

Argument: $ARGUMENTS
