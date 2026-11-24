# Usage

How to read and manipulate the window/workspace/layout state. AeroSpace owns macOS windows; Rex owns terminal blocks. Read state first; act second.

## State

```sh
./scripts/layout.sh          # human-readable
./scripts/layout.sh --json   # machine-readable
```

Prints monitors, workspaces (focused/visible/root-layout), windows (workspace, id, app, title, layout, fullscreen) and the Rex session tree. `--session <label>` limits Rex; Rex is optional.

## Raw queries (when you need more)

```sh
# AeroSpace (placeholders: window-id, app-name, window-title, window-layout,
# workspace, workspace-is-focused, workspace-is-visible, workspace-root-container-layout,
# monitor-id, monitor-name, monitor-is-main)
aerospace list-monitors --format '%{monitor-name} | %{monitor-id} | %{monitor-is-main}'
aerospace list-workspaces --all --format '%{workspace} | %{workspace-is-focused} | %{workspace-is-visible} | %{workspace-root-container-layout}'
aerospace list-windows --all --format '%{workspace} | %{window-id} | %{app-name} | %{window-title} | %{window-layout}'

# Rex
rex session inspect <label> --json   # full layer tree (windows, blocks, splits)
rex ls --json                        # sessions
```

## Manipulation

| Intent | Command |
| --- | --- |
| Focus a workspace | `aerospace workspace <name>` |
| Focus a window by id | `aerospace focus --window-id <id>` |
| Focus a neighbor (left/down/up/right, or dfs-next with `--boundaries-action wrap-around-the-workspace`) | `aerospace focus <direction>` |
| Move a window to a workspace | `aerospace move-node-to-workspace <name>` |
| Move a window to the next monitor | `aerospace move-node-to-monitor --wrap-around next` |
| Resize | `aerospace resize smart +50` |
| Join / split / layout | `aerospace join-with <dir>` · `aerospace split <horizontal|vertical|opposite>` · `aerospace layout` |
| Balance windows | `aerospace balance-sizes` |
| Fullscreen | `aerospace fullscreen` |
| Run a command in a new window | `rex run -- <command>` |
| Run a command beside a block | `rex split -- <command>` |
| Split / zoom / focus / move / send | `rex split --split=below -- <cmd>` · `rex zoom` · `rex focus <block>` · `rex move <dir> <anchor>` · `rex send '<text>'` · `rex send-key enter` |
| Capture a block | `rex capture` |
| Wait for a block or session | `rex wait <target>` |

## Rules

1. Check state before acting. The layout can change between query and action.
2. Use ids and labels (AeroSpace `--window-id`; Rex block label, id, or 6-hex suffix). Never positions.
3. AeroSpace moves macOS windows; Rex splits/zooms terminal blocks. Different layers, don't conflate them.
4. Prefer idempotent commands (`--fail-if-noop`, `--fail-if-fullscreen`) or re-query immediately before acting.
5. Keyboard bindings in `aerospace.toml` are human affordances, not the agent's surface. Do not rely on them.
