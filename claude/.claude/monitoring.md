Watching state and waking yourself up
=====================================

MUST, MUST NOT, SHOULD, SHOULD NOT and MAY have their RFC 2119 meanings.

This file lists what you can observe and how to wake yourself when it changes.
It does not say what to do when it changes. I give that in each situation,
for example "start the agents once the 5-hour window resets" or "pause the agents at 90%".


What you can observe
--------------------

| Variable | How to read it | Freshness and cost |
| :-- | :-- | :-- |
| The 5-hour usage percent and its reset time | `~/.claude/scripts/usage-5h.sh` prints `<percent> <reset epoch>`. Exit 1 means there is no OAuth token, and exit 2 prints `http=<code> retry-after=<seconds>` on stderr | Current, from the usage endpoint that `/usage` reads. One HTTP request and no model calls |
| The same, cached | `~/.cache/dotfiles/claude/usage-5h`, written by the status line on every render | Stale while the main chat is idle, even while agents spend |
| The 7-day usage percent and its reset time | `~/.cache/dotfiles/claude/usage-7d`, in the same format | Only the status line writes it, so it has the same staleness |
| A background command, an agent or a workflow finishing | The harness's completion notification | Arrives on its own |
| Another session going idle | `SendMessage` with `notify_when_idle: true` | One notice |
| The sessions and agents that exist, and whether each is busy | `ListAgents` | A snapshot |
| Anything a shell command can test | A file, a port, a log line, a container's health with `docker inspect`, a git ref, a CI job's status | As fresh as the command |


How to wake yourself
--------------------

Choose the mechanism by what you are waiting for.

| Waiting for | Mechanism |
| :-- | :-- |
| Work the harness tracks: a background command, an agent or a workflow | Nothing. Its notification wakes you. You MUST NOT poll its output or set a timer for it |
| One condition, such as a server answering or a file appearing | `Bash` with `run_in_background` and `until <test>; do sleep <seconds>; done`. It exits once, so you get one notification |
| A time | `Bash` with `run_in_background` and `sleep <seconds>`, computed from `date +%s`. A foreground `sleep` is blocked |
| The usage window's reset | `WAIT_THRESHOLD=0 ~/.claude/scripts/wait-for-usage-reset.sh` with `run_in_background`, outside the sandbox. It sleeps until a minute past the reset that the cache records and prints `RESET`. Without `WAIT_THRESHOLD=0` it only waits when a window is at 50% or more |
| A stream of events, each of which you act on | `Monitor`, with a command that prints one line per event. The command's filter also matches every failure. A monitor expires after at most 30 minutes, so re-arm it on expiry while you still need it |
| Usage crossing thresholds | `Monitor` running `~/.claude/scripts/usage-monitor.sh 80 90 95`, outside the sandbox. It prints a line the first time the 5-hour usage reaches each threshold, polling every `USAGE_POLL` seconds (default 300) |
| A time I name, while the main chat is idle | `CronCreate`, one-shot. It only fires while the chat is idle and is lost when the session ends |
| The next step of a `/loop` | `ScheduleWakeup` |

* When you set up a wake-up, you MUST tell me in one line what will wake you and roughly when.
* On waking, you MUST read the variable again before you act, because a reset time can move and a condition can
  change back. For usage, run `usage-5h.sh` rather than trusting the cache.
* A wait MUST end on failure as well as success. A loop that waits for a server also gives up after a time
  you state, and prints why.
* Before you start work that spends many tokens, such as several agents or a workflow, you SHOULD read the
  5-hour usage and tell me the percent and the reset time.


Pausing and resuming agents
---------------------------

When I ask you to pause work at a threshold and resume it later:

1. Send each agent you can message: "Usage limit near. Stop at the end of your current step and reply with
   your task, what is complete with paths and commits, what is in progress and its exact state, and the
   next step. Then do nothing more." A background agent that has not returned cannot be stopped mid-step
   except with `TaskStop`, which loses its work in progress, so wait for its report instead.
2. Write a handoff file in the scratchpad: the goal, what is done, what is in progress, decisions taken, and
   for each agent its prompt, its report and the prompt that relaunches it as a continuation. For a workflow,
   note its run id for `resumeFromRunId`.
3. Wait for the reset as the table above says, then read the usage again, and relaunch each agent from the
   handoff file.
