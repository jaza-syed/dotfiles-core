#!/bin/bash
# Blocks until the claude.ai 5-hour or 7-day usage reaches PERSIST_ALERT percent (default
# 95), then prints the persist procedure for the given session.
# usage: persistent-watch.sh <session-id>
#   exit 0  printed the procedure
#   exit 1  printed ERROR: no usage was recorded within WATCH_GRACE seconds
# Reads ~/.cache/dotfiles/claude/usage-5h and usage-7d every WATCH_POLL seconds (default
# 30). The status line rewrites those files on every render, so they are current whenever
# Claude Code is working and stale only while it is idle and spending nothing. Makes no
# network and no model calls.
id="$1"; threshold="${PERSIST_ALERT:-95}"; poll="${WATCH_POLL:-30}"; grace="${WATCH_GRACE:-900}"
dir="$HOME/.cache/dotfiles/claude"; missing=0
while :; do
  if [ -r "$dir/usage-5h" ]; then
    missing=0
    read -r pct5 _ <"$dir/usage-5h"; pct5=${pct5%%.*}
    pct7=0; [ -r "$dir/usage-7d" ] && { read -r pct7 _ <"$dir/usage-7d"; pct7=${pct7%%.*}; }
    [ "$pct5" -ge "$threshold" ] 2>/dev/null && { which="5-hour usage is at ${pct5}%"; break; }
    [ "$pct7" -ge "$threshold" ] 2>/dev/null && { which="7-day usage is at ${pct7}%"; break; }
  else
    missing=$(( missing + poll ))
    [ "$missing" -ge "$grace" ] && { echo "ERROR no usage recorded at $dir/usage-5h"; exit 1; }
  fi
  sleep "$poll"
done
echo "$which and this session is persistent. Do the following now, before any other work."
echo
sed "s/\${CLAUDE_SESSION_ID}/$id/g" "${0%.sh}.md"
