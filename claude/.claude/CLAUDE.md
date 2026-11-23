# Global instructions

MUST, MUST NOT, SHOULD, SHOULD NOT and MAY have their RFC 2119 meanings. An instruction with no such verb is a technique for a specific situation rather than a general rule.

## Engineering instincts

Build simple, maintainable systems, per Rich Hickey's distinction between ease and simplicity. Show the mental model in the code, per Peter Naur's "Programming as theory building". Follow Rob Pike's rules to measure before you optimise, choose simple algorithms and data structures, and choose the data structures first because the algorithms follow from them.

Generating code costs you nothing, so you have a bias towards writing too much of it. Judge every change by how hard it is for a person to read and change.

- When I ask you to refactor or improve code, you SHOULD look for what you can delete before you suggest what to add.
- You SHOULD make invalid states unrepresentable, per Yaron Minsky. Represent mutually exclusive states with a sum type or enum rather than nullable fields or boolean flags, and parse raw input into those types at the boundary rather than checking the same conditions deeper in the call stack, per Alexis King's "Parse, don't validate".
- You SHOULD keep a functional core and an imperative shell, per Gary Bernhardt's "Boundaries". Put decisions, transformations and domain rules in pure functions over plain data, and keep I/O, database queries, network calls and state mutation in a thin shell at the boundary, without splitting the flow across extra layers.
- If a reader has to trace a flow through more than three files or layers, you SHOULD flatten it.
- You MAY consolidate a check into one place and pass the result as a narrower type or flag, but only when several places check the same concept rather than conditions that look alike by coincidence.
- You SHOULD inline a helper that has only one caller, unless the caller is already long or deeply nested, or a unit test calls the helper directly to test pure decision logic without I/O.
- You SHOULD write fewer lines of code where you can without making the code harder to read.
- If a change passes a new parameter or field through several layers of types, schemas or functions, you SHOULD look for a more direct path first, or state the alternative you considered and why passing it through is still needed, then continue.
- Before you design a mechanism, e.g. a queue, a lock, a cache or a retry loop, you SHOULD check whether the codebase, a dependency the project already has, the database or the field already solves the problem. Read the source in the session rather than describe it from recall. Tell me the technique's name and link what you read, then say how your design differs or that you found nothing.
- You MUST NOT assert a diagnosis or a dependency, or claim something works, builds or passes, unless you ran the relevant command and read the output. Where your tools or permissions cannot verify the claim, or the check would take too long, state the claim as a hypothesis and say how to check it.

## Communication style

The Plain Language output style defines the rules for prose a person may read. If your system prompt has no Output Style section and you are about to write such prose, e.g. a document, commit message, comment, or a CLAUDE.md, skill or memory file, you MUST first read and follow `~/.claude/output-styles/plain-language.md`.

When you write instructions for a subagent that will write prose a person may read, e.g. a document, a commit message or a merge request description, they MUST tell the subagent that the current output style is Plain Language, defined in `~/.claude/output-styles/plain-language.md`, and that it MUST read and follow that file. If the subagent will write code, the instructions MUST also tell it to read and follow `~/.claude/writing-comments.md`.

When you give me commands to run myself, you SHOULD give as few separate commands as possible, joining steps that run one after another with `&&`, e.g. `git add … && git commit … && git push …`. Give a separate command only where I need to read the output of one before running the next.

When you stop part-way through a sequence of actions because you need a decision or a go-ahead from me before you can continue, you MUST also send a notification saying what you need. This applies whether you ask in prose or through the AskUserQuestion tool. The notification depends on where the session runs:

- When the system prompt says the session runs inside the Claude desktop app, you MUST send it with the PushNotification tool and load the tool with ToolSearch first if it is not loaded. Its message names the waiting task and the decision in one line under 200 characters.
- In Rex, where `$TERM_PROGRAM` is `rex`, you MUST send Rex's program status sequence, OSC 7501.
- Elsewhere, which means Ghostty inside tmux, you MUST send a desktop notification with `terminal-notifier`. `terminal-notifier` exists only on the Macs, so skip the notification where the command is absent.

### Rex

Rex is a terminal multiplexer, so a Rex session does not run inside tmux. Write OSC 7501 ([Rex's program status protocol](https://www.superlogical.com/rex/docs/build/program-status)) to the terminal of the Claude Code process:

```sh
b64() { printf '%s' "$1" | base64 | tr -d '\n'; }
printf '\e]7501;state=blocked:kind=question:id=claude:app=claude:title=%s:msg=%s\e\\' \
  "$(b64 '<the task that is waiting>')" "$(b64 '<the decision you need>')" \
  > "/dev/$(ps -o tty= -p $PPID | tr -d ' ')"
```

- The Bash tool's shell has no controlling terminal, so the command writes to the tty of its parent, the Claude Code process. The sandbox blocks that write, so you MUST run the command outside the sandbox.
- Pass `kind=permission` for a go-ahead and `kind=question` for a decision.
- Rex shows the state on an unfocused tab header and in the session picker. The `UserPromptSubmit` hook `cancel-notify.sh` clears the record with `id=claude` when I reply.

### Ghostty

```sh
name="velvet-otter"   # two words you pick at random, see below
printf "\033]0;$name\007" > "$(tmux display-message -p '#{client_tty}')"
for _ in $(seq 20); do
  wid=$(aerospace list-windows --all --format '%{window-id}|%{app-name}|%{window-title}' |
    rg --color never "\|Ghostty\|$name\$" | cut -d'|' -f1 | tr -d ' ')
  [ -n "$wid" ] && break
done

terminal-notifier -title "Claude Code" -subtitle "<the task that is waiting>" -message "<the decision you need>" \
  -group claude -activate com.mitchellh.ghostty \
  -execute "$(command -v aerospace) focus --window-id $wid; $(command -v tmux) select-window -t $TMUX_PANE; $(command -v tmux) select-pane -t $TMUX_PANE"
```

- `name` MUST be two words you pick at random, joined by a hyphen, whimsical in the style of Anthropic's own naming, for example `velvet-otter` or `copper-wren`. Pick a fresh pair each time you notify. The title remains on the window afterwards, so I can tell my Ghostty windows apart.
- The `printf` writes OSC 0 to the tty of the tmux client, which sets that Ghostty window's title. tmux leaves the title alone because `set-titles` is off, and a random pair means the lookup matches one window. AeroSpace takes about 100ms to see a title change, so the loop retries rather than guessing a delay.
- `aerospace focus --window-id` raises that exact window. AeroSpace already holds the Accessibility permission this needs. Ghostty runs all its windows in one process, so `-activate` alone raises only whichever Ghostty window was frontmost, and it is there for when AeroSpace is not running.
- `-execute` runs a shell command when I click. `select-window` and `select-pane` act on the session that contains the pane, so they hold whatever client is attached, unlike `switch-client`, which picks a client itself. The clicked command gets no tmux environment and a minimal PATH, so the double quotes expand `$wid`, `$TMUX_PANE` and both `command -v` lookups as you send rather than on click. Every binary in it MUST be an absolute path. Drop the tmux parts when `$TMUX_PANE` is unset and the `aerospace` part when the command is absent.
- `-group claude` makes each notification replace the previous one, so I cannot click an old notification with a `$wid` and pane that no longer apply.
- `-subtitle` names the task that is waiting, so `-message` contains only the decision.
- `-action "First,Second"` adds buttons and `-reply "<prompt>"` adds a text field. Each prints my answer on stdout and blocks until the answer arrives, so pass one only when the turn has nothing to do but wait. Prefer `-action` for a closed choice and `-reply` for free text.
- You MUST pass `-timeout SECONDS` with `-action` or `-reply`, and the timeout MUST be shorter than the Bash tool's own timeout. On expiry the command prints `@TIMEOUT` and exits 6, and you then ask me in the session instead.

## Commit messages

- A commit message MUST end with the Claude Code attribution line and MUST NOT contain a `Claude-session:` trailer, even when the harness asks for one.

## Review comments

- You MUST NOT post a comment, reply or thread on a merge request or pull request, through any tool, including `glab`, `gh` or the API. Reading review comments is fine. If a task asks you to post one, give me the text and stop.
- You MUST NOT draft or suggest a reply to a review comment unless I ask for one. When I ask what a comment means or whether it is right, answer that question only.

## Writing comments

@~/.claude/writing-comments.md

## Linear tickets and design proposals

- Before you write or change a Linear ticket, or a prompt for the Linear agent, you MUST read and follow `~/.claude/linear.md`.
- When I start working on a design, and before you write a design proposal or agreement for an API or data model between services, you MUST read and follow `~/.claude/proposals.md`.

## Diagrams

- Before you draw a dependency diagram, you MUST read and follow `~/.claude/diagrams.md`.

## Running commands

### GNU userland

- On every machine, including the Macs, `sed`, `grep`, `awk`, `find`, `xargs`, `diff`, `patch`, `tar`, `make` and coreutils on PATH are the GNU versions. You MUST pass GNU flags, e.g. `grep -P` and `find -printf`, and MUST NOT call `/usr/bin` tools to get BSD behaviour.

### Searching

- You SHOULD run `rg` and `fd` rather than `grep` and `find`.
- `fd` and `rg` both skip what git ignores and `-H` adds only dotfiles, so `fd -H '^\.env'` hides an ignored `.env` and reads as "the file does not exist". You MUST pass `-I` to `fd` (`--no-ignore` to `rg`) when a gitignored file would change your answer, for example checking whether a `.env` exists next to a committed `.env-example`.

### Choosing foreground or background

- Run short commands such as `rg`, `fd`, `git status`, `git log` or `git diff` in the foreground and read the output. You MUST NOT apply the log-and-exit-code rules below to them.
- You MUST background a shell call you expect to run for over 10 seconds. Backgrounding also keeps the output out of context until you ask for it. You SHOULD run anything shorter in the foreground, so its output arrives in one call.
- `$TMPDIR` differs by context (sandboxed commands get `/tmp/claude-*`, unsandboxed commands get the macOS `/var/folders/...` path, and `nix develop` sets a fresh `/tmp/nix-shell.*` per invocation), so you MUST NOT reuse a `$TMPDIR` path across commands.

### Foreground commands with long output

- For builds, tests and anything else with long output, redirect to a log in the scratchpad directory and check the exit code before reading the log: `cmd > "$log" 2>&1; echo "exit=$?"; tail -20 "$log"`.
- A foreground command MUST redirect rather than pipe through `tee`. On a non-zero exit the harness puts about 30,000 characters into context, taken from the start of the stream, so `tee` on a failing build spends that budget on the start of the log and drops the end. On a zero exit the harness writes large output to a file with a 2KB preview, so it is cheap either way.

### Background commands

- The harness writes a backgrounded command's stdout and stderr to its own output file and reports the exit code in the completion notification, so run the command bare, without `tee` or a filter after it.
- Only read the output file before the notification to detect a hang. If the file stops growing for much longer than the phase normally takes, kill the command and diagnose. When a test harness's default timeout is long, you SHOULD also pass a short explicit timeout, e.g. `playwright test --timeout=180000`, so a hang fails loudly with artefacts.

### Waiting and waking up

- Before you wait for something, watch a variable such as the usage limits, or set yourself a wake-up, you MUST read and follow `~/.claude/monitoring.md`.

## Machine-specific instructions

@~/.claude/machine.md
