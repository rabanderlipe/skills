#!/usr/bin/env bash
# TeammateIdle hook. Two jobs, both bounded so a teammate is never kept in a loop:
# 1. Quality gate: when an engineer (eng-*) goes idle and .claude/team-gate.sh fails,
#    send it back with the output, up to 3 times per engineer per session. This works
#    whether or not the session has the Task tools.
# 2. Nudge: the first time any teammate goes idle, send it back once to check its
#    "Done when" line and report.
set -uo pipefail
input=$(cat)
here=$(dirname "$0")
"$here/log-event.sh" "$input"
teammate=$(jq -r '.teammate_name // empty' <<<"$input")
session=$(jq -r '.session_id // empty' <<<"$input")
cwd=$(jq -r '.cwd // empty' <<<"$input")
[[ -n $teammate && -n $session ]] || exit 0
state="$HOME/.claude/agent-team/state"
mkdir -p "$state" 2>/dev/null || exit 0

if [[ $teammate == eng-* ]] && ! out=$("$here/run-gate.sh" "${cwd:-.}" "$teammate"); then
  count_file="$state/$session-$teammate.gate"
  count=$(cat "$count_file" 2>/dev/null || echo 0)
  if (( count < 3 )); then
    echo $((count + 1)) >"$count_file"
    {
      echo "$out"
      echo "Fix these before going idle, then rerun the gate (bash .claude/team-gate.sh)."
      echo "If a failure is in a file you don't own, message the tech-lead (or the planner) with it instead."
    } >&2
    exit 2
  fi
  jq -nc --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg cwd "$cwd" --arg s "$session" --arg t "$teammate" \
    '{ts:$ts,event:"GateGaveUp",cwd:$cwd,session:$s,teammate:$t,task_id:null,task:null}' >>"$HOME/.claude/agent-team/log.jsonl"
fi

mark="$state/$session-$teammate.nudged"
[[ -e $mark ]] && exit 0
touch "$mark"
cat >&2 <<MSG
Before going idle, check your role's "Done when" line. If it is met, make sure your
output file is written, your shared task (if any) is marked completed, and you messaged
its path and evidence to whoever handed you the work. If you are blocked, message the
planner with the blocker and what you need. If all of that is already done, go idle.
MSG
exit 2
