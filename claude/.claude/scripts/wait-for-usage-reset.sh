#!/bin/bash
# Blocks until the claude.ai usage window that is over WAIT_THRESHOLD percent has reset, by
# sleeping until the latest reset time the status line recorded for such a window.
# usage: wait-for-usage-reset.sh [max_seconds]
#   exit 0  printed RESET
#   exit 3  printed WAITING: the reset is further off than max_seconds; run it again
#   exit 1  printed ERROR: no reset time is recorded
# Reads ~/.cache/dotfiles/claude/usage-5h and usage-7d, which the status line rewrites on
# every render, and falls back to usage-5h.sh only when the 5h file is absent. Makes no
# model calls. The cache is rewritten only on a render, so after a RESET run it once more:
# a second RESET at once means every window is below the threshold.
MAX="${1:-0}"; THRESHOLD="${WAIT_THRESHOLD:-50}"; here=$(dirname "$0")
dir="$HOME/.cache/dotfiles/claude"

fmt() { date -d "@$1" '+%a %H:%M %Z' 2>/dev/null || date -r "$1" '+%a %H:%M %Z'; }

if [ -r "$dir/usage-5h" ]; then
  read -r pct5 resets5 <"$dir/usage-5h"
elif out=$("$here/usage-5h.sh" 2>/dev/null); then
  read -r pct5 resets5 <<<"$out"
else
  echo "ERROR no reset time at $dir/usage-5h and the usage endpoint is unavailable"; exit 1
fi
pct7=0; resets7=0
[ -r "$dir/usage-7d" ] && read -r pct7 resets7 <"$dir/usage-7d"
pct5=${pct5%%.*}; resets5=${resets5%%.*}; pct7=${pct7%%.*}; resets7=${resets7%%.*}

# The target is the latest reset among the windows over the threshold.
target=0; label=""
[ "$pct5" -ge "$THRESHOLD" ] && { target=$resets5; label="5h ${pct5}%"; }
[ "$pct7" -ge "$THRESHOLD" ] && [ "$resets7" -gt "$target" ] && { target=$resets7; label="7d ${pct7}%"; }
[ "$target" -eq 0 ] && { echo "RESET usage 5h ${pct5}%, 7d ${pct7}%"; exit 0; }

# Land a minute past the reset so the window has certainly rolled over.
nap=$(( target + 60 - $(date +%s) )); [ "$nap" -lt 0 ] && nap=0
if [ "$MAX" -gt 0 ] && [ "$nap" -gt "$MAX" ]; then
  echo "WAITING $label, window resets at $(fmt "$target")"; exit 3
fi
echo "SLEEPING ${nap}s until $(fmt $(( target + 60 ))) for the $label window"
sleep "$nap"
echo "RESET $label window reset at $(fmt "$target")"
