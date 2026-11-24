#!/bin/bash
# Read-only snapshot of the window/workspace/layout state, for an agent (or a
# human) to read before it manipulates layout. AeroSpace reports macOS windows;
# Rex reports terminal sessions. Run it before acting on "windows", "workspaces",
# "monitors", "blocks" or "layout".
#
#   Usage: layout.sh [--json] [--session LABEL] [--help]
#
#   --json           emit machine-readable JSON (default: human-readable)
#   --session LABEL  limit the Rex section to one session (default: all)
#
# AeroSpace is required. Rex is optional: if the server is unreachable, the
# Rex section is skipped with a note.
set -euo pipefail

JSON_MODE=0
SESSION=""
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON_MODE=1; shift ;;
    --session) SESSION="${2:?--session needs a value}"; shift 2 ;;
    --session=*) SESSION="${1#--session=}"; shift ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "layout.sh: unknown flag: $1" >&2; exit 2 ;;
  esac
done

# ASCII 0x1 separator: never appears in titles, labels, or ids.
SEP=$'\x01'

monitors_raw=$(aerospace list-monitors --format "%{monitor-name}${SEP}%{monitor-id}${SEP}%{monitor-is-main}")
workspaces_raw=$(aerospace list-workspaces --all --format "%{workspace}${SEP}%{workspace-is-focused}${SEP}%{workspace-is-visible}${SEP}%{workspace-root-container-layout}")
windows_raw=$(aerospace list-windows --all --format "%{workspace}${SEP}%{window-id}${SEP}%{app-name}${SEP}%{window-title}${SEP}%{window-layout}${SEP}%{window-is-fullscreen}")

# Mixed raw lines -> array of objects (each jq call starts with a literal array).
monitors_json=$(printf '%s\n' "$monitors_raw" | jq -R -cs -c 'split("\n") | map(select(length > 0)) | map(split("\u0001")) | map({monitor_name: .[0], monitor_id: (.[1]|tonumber? // .[1]), is_main: (.[2] == "true")})')
workspaces_json=$(printf '%s\n' "$workspaces_raw" | jq -R -cs -c 'split("\n") | map(select(length > 0)) | map(split("\u0001")) | map({workspace: .[0], is_focused: (.[1] == "true"), is_visible: (.[2] == "true"), root_layout: .[3]})')
windows_json=$(printf '%s\n' "$windows_raw" | jq -R -cs -c 'split("\n") | map(select(length > 0)) | map(split("\u0001")) | map({workspace: .[0], window_id: (.[1]|tonumber? // .[1]), app_name: .[2], window_title: .[3], layout: .[4], is_fullscreen: (.[5] == "true")})')

# Rex is optional: warn and continue if the server is unreachable.
rex_note=""
rex_json='[]'
if command -v rex >/dev/null 2>&1; then
  rex_sessions=$(rex ls --json 2>/dev/null | jq -r '.sessions[].label' 2>/dev/null) || rex_sessions=""
  if [ -z "$rex_sessions" ]; then
    rex_note="rex: no sessions (server unreachable or empty)"
  else
    collected=()
    while IFS= read -r label; do
      [ -n "$label" ] || continue
      if [ -n "$SESSION" ] && [ "$label" != "$SESSION" ]; then continue; fi
      detail=$(rex session inspect "$label" --json 2>/dev/null) || { rex_note="rex: could not inspect session $label"; continue; }
      focused_block=$(printf '%s' "$detail" | jq -r '.windows[].focused_block_id // empty' 2>/dev/null | head -1 | grep -oE '[0-9a-f]{6}$' || true) || focused_block=""
      windows_detail=$(printf '%s' "$detail" | jq -c '[.windows[] | {label: .label, focused_block_id: .focused_block_id, blocks: ([.layers[].blocks[]?] | length), layers: [.layers[] | {kind: .kind, split: (if .layout.split then {direction: .layout.split.direction, ratio: .layout.split.ratio, before_block: (.layout.split.before.block_id // null), after_block: (.layout.split.after.block_id // null)} else null end)}]}]' 2>/dev/null) || windows_detail="[]"
      blocks_json=$(printf '%s' "$detail" | jq -c '[.windows[].layers[].blocks[]? | {block_id: .block_id, short: (.block_id | capture("(?<s>[0-9a-f]{6})$").s), label: .label, flavor: .flavor, owner: .owner}] | unique_by(.block_id)' 2>/dev/null) || blocks_json="[]"
      obj=$(jq -n -c \
        --arg label "$label" \
        --arg focused "${focused_block:-}" \
        --argjson windows "$windows_detail" \
        --argjson blocks "$blocks_json" \
        '{label: $label, focused_block: (if $focused == "" then null else $focused end), windows: $windows, blocks: $blocks}' 2>/dev/null) || obj="{}"
      collected+=("$obj")
    done <<< "$rex_sessions"
    if [ ${#collected[@]} -gt 0 ]; then
      rex_json=$(printf '%s\n' "${collected[@]}" | jq -c -s '.') || rex_json='[]'
    fi
    [ -n "$rex_note" ] || [ "$rex_json" != "[]" ] || rex_note="rex: no sessions (server unreachable or empty)"
  fi
fi
[ -z "$rex_note" ] && [ "$rex_json" = "[]" ] && rex_note="rex: no sessions (server unreachable or empty)"

if [ "$JSON_MODE" = "1" ]; then
  jq -n -c \
    --argjson monitors "$monitors_json" \
    --argjson workspaces "$workspaces_json" \
    --argjson windows "$windows_json" \
    --argjson rex "$rex_json" \
    --arg rex_note "$rex_note" \
    '{monitors: $monitors, workspaces: $workspaces, windows: $windows, rex: $rex} + (if $rex_note == "" then {} else {note: $rex_note} end)'
  exit 0
fi

truncate() {
  local s="$1" n="${2:-70}"
  if [ ${#s} -gt "$n" ]; then printf '%s…' "${s:0:$((n-1))}"; else printf '%s' "$s"; fi
}

printf 'MONITORS\n'
jq -r '.[] | "  \(.monitor_name) (id=\(.monitor_id), main=\(.is_main))"' <<< "$monitors_json"
printf '\nWORKSPACES\n'
jq -r '.[] | "  \(.workspace)\tvis=\(.is_visible)\tfocused=\(.is_focused)\troot=\(.root_layout)"' <<< "$workspaces_json"
printf '\nWINDOWS\n'
printf '%s' "$windows_json" | jq -r '.[] | [.workspace, .window_id, .app_name, .window_title, .layout, .is_fullscreen] | @tsv' | while IFS=$'\t' read -r ws wid app title layout fullscreen; do
  printf '  %s | %s | %s | %s | %s | fullscreen=%s\n' "$ws" "$wid" "$app" "$(truncate "$title")" "$layout" "$fullscreen"
done
printf '\nREX\n'
if [ "$rex_json" != "[]" ]; then
  jq -r '.[] | "session \(.label) | windows: \(.windows|length) | blocks: \(.blocks|length)" + (if .focused_block != null then " | focused block \(.focused_block)" else "" end)' <<< "$rex_json"
  jq -r '.[].windows[] | .layers[]? | select(.split != null) | "  layout: \(.split.direction) ratio=\(.split.ratio)  before=\(.split.before_block // "?" | sub(".*-"; "") | .[-6:])  after=\(.split.after_block // "?" | sub(".*-"; "") | .[-6:])"' <<< "$rex_json"
  jq -r '.[].blocks[] | "  \(.short)\t\(.label)\t\(.flavor)\towner=\(.owner)"' <<< "$rex_json"
else
  printf '  %s\n' "$rex_note"
fi
