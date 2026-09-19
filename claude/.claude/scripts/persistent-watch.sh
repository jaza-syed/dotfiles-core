#!/bin/bash
# Blocks until the claude.ai 5-hour usage reaches PERSIST_ALERT percent (default 95),
# then prints the persist procedure for the given session.
# usage: persistent-watch.sh <session-id>
#   exit 0  printed the procedure
#   exit 1  printed ERROR: usage could not be read 10 times in a row
# Polls usage-5h.sh every WATCH_POLL seconds (default 60). Makes no model calls.
id="$1"; threshold="${PERSIST_ALERT:-95}"; poll="${WATCH_POLL:-60}"; here=$(dirname "$0"); fails=0
while :; do
  if read -r pct _ < <("$here/usage-5h.sh"); then
    fails=0
    [ "$pct" -ge "$threshold" ] && break
  else
    fails=$((fails + 1)); [ "$fails" -ge 10 ] && { echo "ERROR cannot read usage"; exit 1; }
  fi
  sleep "$poll"
done
echo "5-hour usage is at ${pct}% and this session is persistent. Do the following now, before any other work."
echo
sed "s/\${CLAUDE_SESSION_ID}/$id/g" "${0%.sh}.md"
