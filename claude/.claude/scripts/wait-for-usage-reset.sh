#!/bin/bash
# Blocks until the claude.ai 5-hour usage window has reset.
# usage: wait-for-usage-reset.sh [max_seconds]
#   exit 0  printed RESET: usage is below WAIT_THRESHOLD (default 50%)
#   exit 3  printed WAITING: max_seconds elapsed first; run it again
#   exit 1  could not read usage
# Polls usage-5h.sh every WAIT_POLL seconds (default 900). Makes no model calls, so
# waiting uses none of the limit.
MAX="${1:-0}"; THRESHOLD="${WAIT_THRESHOLD:-50}"; POLL="${WAIT_POLL:-900}"; start=$(date +%s)
while :; do
  read -r pct resets < <("$(dirname "$0")/usage-5h.sh") || { echo "ERROR cannot read usage"; exit 1; }
  [ -z "$pct" ] && { echo "ERROR cannot read usage"; exit 1; }
  now=$(date +%s)
  if [ "$pct" -lt "$THRESHOLD" ]; then echo "RESET usage ${pct}%"; exit 0; fi
  until_reset=$(( resets - now + 60 )); [ "$until_reset" -lt "$POLL" ] && nap=$until_reset || nap=$POLL
  [ "$nap" -lt 30 ] && nap=30
  if [ "$MAX" -gt 0 ] && [ $(( now - start + nap )) -gt "$MAX" ]; then
    echo "WAITING usage ${pct}%, window resets at $(date -d "@$resets" '+%H:%M %Z' 2>/dev/null || date -r "$resets" '+%H:%M %Z')"; exit 3
  fi
  sleep "$nap"
done
