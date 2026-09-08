#!/usr/bin/env zsh
# Claude Code status line, two rows: user@host, dir, branch and model on the first;
# Ctx, 5h and 7d usage line2 with time to reset on the second.

input=$(cat)

IFS=$'\t' read -r model ctx five five_at seven seven_at cwd <<<"$(jq -r '
  [ (.model.display_name // "?"),
    (.context_window.used_percentage // -1),
    (.rate_limits.five_hour.used_percentage // -1),
    (.rate_limits.five_hour.resets_at // -1),
    (.rate_limits.seven_day.used_percentage // -1),
    (.rate_limits.seven_day.resets_at // -1),
    (.workspace.current_dir // .cwd // "")
  ] | @tsv' <<<"$input")"

BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
BLUE=$'\033[1;34m'; PURPLE=$'\033[1;35m'; MAGENTA=$'\033[35m'
GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'
now=$(date +%s)

# Git branch, abbreviated to the Linear ticket id like the starship config.
git_branch=""
if [[ -n $cwd ]] && git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  raw_branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
  if [[ -n $raw_branch ]]; then
    git_branch=$(printf '%s' "$raw_branch" | sed -E \
      -e 's@^(feature|bugfix|refactor|hotfix)/([[:alpha:]]+-[[:digit:]]+)-.*$@\1/\2@' \
      -e 's@^(feature|bugfix|refactor|hotfix)/.*-([[:alpha:]]+-[[:digit:]]+)$@\1/\2@')
  fi
fi

# bar <pct> <yellow-from> <red-above> -> coloured "███░░░░░░░ 31%"; fails if pct absent
bar() {
  local p=${1%%.*} t1=$2 t2=$3 colour cells="" i filled width=6
  [[ $p =~ ^[0-9]+$ ]] || return 1

  if   ((p < t1));  then colour=$GREEN
  elif ((p <= t2)); then colour=$YELLOW
  else                   colour=$RED
  fi

  filled=$(((p * width + 50) / 100))
  ((filled > width)) && filled=$width
  for ((i = 0; i < width; i++)); do
    if ((i < filled)); then cells+="█"; else cells+="░"; fi
  done

  printf '%s%s %s%%%s' "$colour" "$cells" "$p" "$RESET"
}

# eta <epoch> -> "1h4m" / "58m"; fails if absent or already elapsed
eta() {
  local at=${1%%.*} secs
  [[ $at =~ ^[0-9]+$ ]] || return 1
  secs=$((at - now))
  ((secs <= 0)) && return 1

  if ((secs >= 3600)); then printf '%dh%dm' $((secs / 3600)) $(((secs % 3600) / 60))
  else                      printf '%dm' $((secs / 60))
  fi
}

# seg <label> <pct> <yellow-from> <red-above> [reset-epoch]
seg() {
  local b t
  b=$(bar "$2" "$3" "$4") || return 0
  [[ -n $line2 ]] && line2+="  ${DIM}|${RESET}  "
  line2+="${DIM}${1}${RESET} ${b}"
  if t=$(eta "${5--1}"); then line2+=" ${DIM}·${t}${RESET}"; fi
}

line1="${BOLD}$(whoami)@$(hostname -s)${RESET}  ${BLUE}${cwd/#$HOME/~}${RESET}"
[[ -n $git_branch ]] && line1+="  ${PURPLE} ${git_branch}${RESET}"
line1+="  ${DIM}|${RESET}  ${MAGENTA}${model}${RESET}"

line2=""
seg Ctx "$ctx"   50 70
seg 5h  "$five"  50 80 "$five_at"
seg 7d  "$seven" 50 80 "$seven_at"

printf '%s' "$line1"
[[ -n $line2 ]] && printf '\n%s' "$line2"
