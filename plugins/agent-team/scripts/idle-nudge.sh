#!/usr/bin/env bash
# TeammateIdle hook. The first time a teammate goes idle in a session, sends it back
# once with a reminder to report or flag its blocker. Later idles pass, so a teammate
# is never kept in a loop.
set -uo pipefail
input=$(cat)
"$(dirname "$0")/log-event.sh" "$input"
teammate=$(jq -r '.teammate_name // empty' <<<"$input")
session=$(jq -r '.session_id // empty' <<<"$input")
[[ -n $teammate && -n $session ]] || exit 0
dir="$HOME/.claude/agent-team/nudged"
mkdir -p "$dir" 2>/dev/null || exit 0
mark="$dir/$session-$teammate"
[[ -e $mark ]] && exit 0
touch "$mark"
cat >&2 <<MSG
Before you go idle: if your task is done, make sure you sent your report (what changed,
commands run and their results) to whoever handed you the task and marked the task
completed. If you are blocked, message the lead with the blocker and what you need.
If both are already done, you can go idle now.
MSG
exit 2
