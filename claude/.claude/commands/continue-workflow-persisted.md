---
description: Usage limit near. Stop every agent, save state to a handoff file, wait for the reset, resume.
---
The 5-hour usage window is nearly used up. Persist the workflow state, wait for the reset, then resume from that state.

Handoff file: `~/.claude/${CLAUDE_SESSION_ID}-<description>.md`, where `<description>` is the task in 2 to 5 lowercase words joined by hyphens, e.g. `migrate-auth-to-oidc`.

1. If you are coordinating agent teammates, send each one this message now: "Usage limit near. Stop at the end of your current step and reply with a STATE REPORT: 1) your task in one sentence, 2) what is complete, with file paths and commit hashes, 3) what is in progress and its exact state, 4) the single next step, 5) anything the next run must know." Wait for every report.
   Plain subagents started with the Agent tool cannot be messaged; wait for the ones you are waiting on to return, and treat their return value as their report.
2. Write the handoff file: the project directory, the overall task and goal, what is done, what is in progress, the next step, decisions taken, open questions, and one section per agent containing its type, the prompt you gave it, its STATE REPORT verbatim, and the exact prompt that relaunches it as a continuation.
3. Run `~/.claude/scripts/wait-for-usage-reset.sh 3600 2>&1 | tee "$log"` in the background, with `$log` in the scratchpad directory, then end your turn and do nothing else. Its completion notification wakes you. If the log ends with WAITING, run it again the same way. If it ends with ERROR, tell me the handoff file's path and stop.
4. When the log ends with RESET, read the handoff file, relaunch each agent with its continuation prompt, and continue. Delete the handoff file when the workflow is finished.
