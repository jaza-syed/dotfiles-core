---
description: Set persistent mode. When 5-hour usage reaches 90%, a hook has Claude save every agent's state, wait for the reset, and resume.
---
You are setting persistent mode for this session.

Create the flag, then confirm in one line that persistent mode is on:

mkdir -p ~/.cache/dotfiles/claude/persistent && touch ~/.cache/dotfiles/claude/persistent/${CLAUDE_SESSION_ID}

If the argument is `off`, run `rip ~/.cache/dotfiles/claude/persistent/${CLAUDE_SESSION_ID}` instead and confirm that persistent mode is off.

While the flag exists, the statusline shows "📌 Persistent!". When 5-hour usage reaches 90%, a hook gives you the procedure after your next tool call and reminds you after each later one: collect a STATE REPORT from every agent, write a handoff file under ~/.claude, wait in a background call until the window resets, then relaunch the agents from that file.

Argument: $ARGUMENTS
