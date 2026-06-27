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

# Get current session directory name (hooks run in the same directory as the session)
session_dir=$(basename "$(pwd)")
input=$(cat)
event=$(printf '%s' "$input" | json_get hook_event_name)
ntype=$(printf '%s' "$input" | json_get notification_type)
msg=$(printf '%s' "$input" | json_get message)

title="Claude Code"
case "$event" in
  Notification)
    case "$ntype" in
      permission_prompt) msg="Approve an action to continue" ;;
      idle_prompt) msg="Claude is waiting for your input" ;;
      *) [ -z "$msg" ] && msg="Claude needs your attention" ;;
    esac
    ;;
  Stop) msg="Claude is ready for your next message" ;;
esac

# Escape double quotes for AppleScript
title=${title//\"/\\\"}
subtitle=${session_dir//\"/\\\"}
msg=${msg//\"/\\\"}
sound_name="Glass"

notification="display notification \"$msg\" with title \"$title\""
[ -n "$subtitle" ] && notification="$notification subtitle \"$subtitle\""
osascript -e "$notification sound name \"$sound_name\""
exit 0