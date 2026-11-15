# Global instructions

MUST, MUST NOT, SHOULD, SHOULD NOT and MAY carry their RFC 2119 meanings. An instruction with no such verb is a technique for a specific situation rather than a general rule.

## Engineering instincts

Build simple, maintainable systems and avoid complexity unless it is necessary, per Rich Hickey's distinction between ease and simplicity. Communicate the implicit mental model through the code, per Peter Naur's "Programming as theory building". Follow Rob Pike's rules: measure before you optimize, use simple algorithms and data structures, and choose the data structures first since the algorithms then follow from the data structures.

Generating code costs you nothing, so you have a natural bias towards over-engineering. Judge every solution by the cognitive load it puts on a human maintainer.

- Prefer deletion. When asked to refactor or improve, you SHOULD look for what can be removed before suggesting what can be added.
- Maintain a flat hierarchy. You SHOULD NOT use deep abstractions, and you SHOULD flatten any logic flow that requires tracing through more than 3 files or layers.
- Consolidate decisions. You MAY consolidate a concept into a single source of truth and carry the result as a simple flag, but only when the concept is checked in multiple places and you are confident the checks are the same concept and not superficially similar.
- Prefer inlining. A single-use helper SHOULD be inlined into its caller, unless the caller is already very long or deeply nested.
- Minimize the diff. You SHOULD prefer fewer lines of code where possible, without obfuscation, and reduce boilerplate.
- Question the threading. If a task requires threading a new signal through multiple layers (types, schemas, pipelines, etc.), you SHOULD use a more direct architectural path where one exists, or state the alternative you considered and why the threading is still needed, then continue.
- You MUST NOT assert a diagnosis or a dependency, or claim something works, builds or passes, unless you ran the relevant command and read the output. Where the tools or permissions you have cannot verify the claim, or the check would be too expensive, present the claim as a hypothesis with the check that would confirm it.

## Communication style

The Plain Language output style defines the rules for prose a person may read. If your system prompt has no Output Style section and you are about to write such prose, e.g. a document, commit message, comment, or a CLAUDE.md, skill or memory file, you MUST first read and follow `~/.claude/output-styles/plain-language.md`.

When you write instructions for a subagent, they MUST tell the subagent that the current output style is Plain Language, defined in `~/.claude/output-styles/plain-language.md`, and that it MUST read and follow that file. If the subagent will write code, the instructions MUST also tell it to read and follow `~/.claude/writing-comments.md`.

When you give me commands to run myself, you SHOULD give as few separate commands as possible, joining steps that run one after another with `&&`, e.g. `git add … && git commit … && git push …`. Give a separate command only where I need to read the output of one before running the next.

When you stop part-way through a sequence of actions because you need a decision or a go-ahead from me before you can continue, you MUST also send a desktop notification saying what you need:

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

This applies whether you ask in prose or through the AskUserQuestion tool. `terminal-notifier` exists only on the Macs, so skip the notification where the command is absent.

In a Claude Desktop session, whose system prompt says it runs inside the Claude desktop app, you MUST send the notification with the PushNotification tool instead of the script, and load the tool with ToolSearch first if it is deferred. Its message names the waiting task and the decision in one line under 200 characters. The bullets below apply only to the script.

- `name` MUST be two words you pick at random, joined by a hyphen, whimsical in the style of Anthropic's own naming, for example `velvet-otter` or `copper-wren`. Pick a fresh pair each time you notify. The title stays on the window afterwards, so I can tell my Ghostty windows apart.
- The `printf` writes OSC 0 to the tty of the tmux client, which sets that Ghostty window's title. tmux leaves the title alone because `set-titles` is off, and a random pair means the lookup matches one window. AeroSpace takes about 100ms to see a title change, so the loop retries rather than guessing a delay.
- `aerospace focus --window-id` raises that exact window. AeroSpace already holds the Accessibility permission this needs, so no grant is required. Ghostty runs all its windows in one process, so `-activate` alone can only raise whichever Ghostty window was frontmost; it stays as the fallback for when AeroSpace is not running.
- `-execute` runs a shell command when I click. `select-window` and `select-pane` act on the session that contains the pane, so they hold whatever client is attached, unlike `switch-client`, which picks a client itself. The clicked command gets no tmux environment and a minimal PATH, so the double quotes expand `$wid`, `$TMUX_PANE` and both `command -v` lookups as you send rather than on click. Every binary in it MUST be an absolute path. Drop the tmux parts when `$TMUX_PANE` is unset, and the `aerospace` part when the command is absent.
- `-group claude` makes each notification replace the previous one, so I cannot click a stale notification whose `$wid` and pane no longer apply.
- `-subtitle` names the task that is waiting, so `-message` carries only the decision.
- `-action "First,Second"` adds buttons and `-reply "<prompt>"` adds a text field. Each prints my answer on stdout and blocks until the answer arrives, so use one only when the turn has nothing to do but wait. Prefer `-action` for a closed choice and `-reply` for free text.
- `-timeout SECONDS` MUST accompany `-action` or `-reply`, and MUST be shorter than the Bash tool's own timeout. On expiry the command prints `@TIMEOUT` and exits 6, and you then ask me in the session instead.

## Review comments

- You MUST NOT post a comment, reply or thread on a merge request or pull request, through any tool, including `glab`, `gh` or the API. Reading review comments is fine. If a task seems to call for a post, give me the text and stop.
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

- On every machine, including the Macs, `sed`, `grep`, `awk`, `find`, `xargs`, `diff`, `patch`, `tar`, `make` and coreutils on PATH are the GNU versions. You MUST use GNU flags, e.g. `grep -P` and `find -printf`, and MUST NOT call `/usr/bin` tools to get BSD behaviour.

### Searching

- You SHOULD use `rg` and `fd` over `grep` and `find`.
- `fd` and `rg` both skip what git ignores, and `-H` only adds dotfiles, so `fd -H '^\.env'` hides an ignored `.env` and reads as "the file does not exist". You MUST pass `-I` to `fd` (`--no-ignore` to `rg`) when a gitignored file would change your answer, for example checking whether a `.env` exists next to a committed `.env-example`.

### Choosing foreground or background

- Short commands such as `rg`, `fd`, `git status`, `git log` or `git diff` run plainly in the foreground, and you read the output. You MUST NOT apply the log-and-exit-code rules below to them.
- You MUST background a shell call you expect to run for over 10 seconds. Backgrounding also keeps the output out of context until you ask for it. You SHOULD run anything shorter in the foreground, so its output arrives in one call.
- `$TMPDIR` differs by context (sandboxed commands get `/tmp/claude-*`, unsandboxed commands get the macOS `/var/folders/...` path, and `nix develop` sets a fresh `/tmp/nix-shell.*` per invocation), so you MUST NOT reuse a `$TMPDIR` path across commands.

### Foreground commands with long output

- For builds, tests and anything else with long output, redirect to a log in the scratchpad directory and check the exit code before reading the log: `cmd > "$log" 2>&1; echo "exit=$?"; tail -20 "$log"`.
- A foreground command MUST redirect rather than pipe through `tee`. On a non-zero exit the harness puts about 30,000 characters into context, taken from the start of the stream, so `tee` on a failing build spends that budget on the start of the log and drops the end. On a zero exit large output is persisted to a file with a 2KB preview, so it is cheap either way.

### Background commands

- The harness writes a backgrounded command's stdout and stderr to its own output file and reports the exit code in the completion notification, so run the command bare, without `tee` or a filter after it.
- Read the output file before the notification only to detect a hang. If the file stops growing for much longer than the phase normally takes, kill the command and diagnose. When a test harness's default timeout is long, you SHOULD also pass a short explicit timeout (e.g. `playwright test --timeout=180000`) so a hang fails loudly with artifacts.

## Machine-specific instructions

@~/.claude/machine.md
