#!/bin/bash
# Claude Code notification hook (macOS).
# Reads the hook JSON from stdin and shows a native notification + sound.

if [[ "$(uname)" != "Darwin" ]]; then
  exit 0
fi

json_get() {
  awk -v key="$1" '
  BEGIN { RS = "\0" }
  {
    k = "\"" key "\""
    idx = index($0, k)
    if (idx == 0) { exit }
    rest = substr($0, idx + length(k))
    sub(/^[ \t\r\n]*:[ \t\r\n]*/, "", rest)
    if (substr(rest, 1, 1) != "\"") { exit }   # only handle string values
    rest = substr(rest, 2)
    n = length(rest)
    out = ""
    for (i = 1; i <= n; i++) {
      c = substr(rest, i, 1)
      if (c == "\\") {
        nc = substr(rest, ++i, 1)
        if (nc == "n") out = out "\n"
        else if (nc == "t") out = out "\t"
        else out = out nc
      } else if (c == "\"") {
        break
      } else {
        out = out c
      }
    }
    printf "%s", out
  }'
}

input=$(cat)
event=$(printf '%s' "$input" | json_get hook_event_name)
ntype=$(printf '%s' "$input" | json_get notification_type)
msg=$(printf '%s' "$input" | json_get message)

title="Claude Code"

case "$event" in
  Notification)
    case "$ntype" in
      permission_prompt)
        subtitle="Permission needed"
        [ -z "$msg" ] && msg="Approve an action to continue"
        ;;
      idle_prompt)
        subtitle="Waiting for you"
        [ -z "$msg" ] && msg="Claude is waiting for your input"
        ;;
      *)
        [ -z "$msg" ] && msg="Claude needs your attention"
        ;;
    esac
    ;;
  Stop)
    subtitle="All done"
    msg="Claude is ready for your next message"
    ;;
  *)
    [ -z "$msg" ] && msg="Notification"
    ;;
esac

# Escape double quotes for AppleScript
title=${title//\"/\\\"}
subtitle=${subtitle//\"/\\\"}
msg=${msg//\"/\\\"}

notification="display notification \"$msg\" with title \"$title\""
[ -n "$subtitle" ] && notification="$notification subtitle \"$subtitle\""
osascript -e "$notification sound name \"Glass\""
exit 0