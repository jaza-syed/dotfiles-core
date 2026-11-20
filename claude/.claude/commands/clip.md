---
description: Copy the text you last told me to copy onto the clipboard with OSC 52
---

Write the text you last told me to copy, verbatim, to a file in your scratchpad directory.
Then run this outside the sandbox, with `f` set to that file's path, and tell me in one line how many bytes you sent:

```sh
if [ -n "$TMUX_PANE" ]; then
  tty=$(tmux display-message -p '#{client_tty}')
else
  p=$$
  while [ "$p" -gt 1 ]; do
    t=$(ps -o tty= -p "$p" | tr -d ' ')
    case "$t" in ''|'?'|'??') ;; *) tty=/dev/$t; break ;; esac
    p=$(ps -o ppid= -p "$p" | tr -d ' ')
  done
fi
printf '\033]52;c;%s\007' "$(base64 < "$f" | tr -d '\n')" > "$tty" && wc -c < "$f"
```
