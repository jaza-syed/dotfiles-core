#!/bin/bash
# Prints one line each time the 5-hour usage first reaches one of the thresholds, for Claude Code's Monitor tool.
# usage: usage-monitor.sh [threshold...]   (default 80 90 95)
#   prints "USAGE 5h <percent>% reached <threshold>%, resets at <time>"
#   exit 1  printed ERROR: neither the usage endpoint nor the status line's cache has a reading
# Reads the usage endpoint through usage-5h.sh every USAGE_POLL seconds (default 300), because the status
# line's cache is stale while the main chat is idle and agents spend. Makes no model calls.
[ $# -gt 0 ] || set -- 80 90 95
poll="${USAGE_POLL:-300}"; here=$(dirname "$0"); cache="$HOME/.cache/dotfiles/claude/usage-5h"
fmt() { date -d "@$1" '+%H:%M %Z' 2>/dev/null || date -r "$1" '+%H:%M %Z'; }
reached=""
while :; do
  if out=$("$here/usage-5h.sh" 2>/dev/null); then
    read -r pct resets <<<"$out"
  elif [ -r "$cache" ]; then
    read -r pct resets <"$cache"
  else
    echo "ERROR no usage reading from the endpoint or $cache"; exit 1
  fi
  # A new window starts below every threshold, so the thresholds can be reached again.
  [ "$pct" -lt "$1" ] && reached=""
  for t in "$@"; do
    if [ "$pct" -ge "$t" ] && [[ " $reached " != *" $t "* ]]; then
      reached="$reached $t"
      echo "USAGE 5h ${pct}% reached ${t}%, resets at $(fmt "$resets")"
    fi
  done
  sleep "$poll"
done
