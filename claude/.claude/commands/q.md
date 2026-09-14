---
description: Answer the question only, with no edits and no subagents
---

Answer this question and do nothing else:

$ARGUMENTS

Rules for this turn:

- You MUST NOT edit, create or delete any file, and you MUST NOT run any command that changes state.
- You MUST NOT use the Agent, Workflow or Task tools, and you MUST NOT delegate to a subagent.
- You MAY read files and run read-only commands such as `rg`, `fd`, `git log` and `git diff` to ground the answer.
- Answer in prose. Do not propose a plan or offer to implement anything unless I ask.
