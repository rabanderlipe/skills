#!/usr/bin/env bash
# TaskCompleted hook. When an engineer (teammate named eng-*) marks a task done, runs
# the project's gate script, .claude/team-gate.sh, and refuses the completion (exit 2,
# output fed back to the engineer) if it fails. Projects without a gate script, and
# other teammates' tasks, pass straight through.
set -uo pipefail
input=$(cat)
"$(dirname "$0")/log-event.sh" "$input"
teammate=$(jq -r '.teammate_name // empty' <<<"$input")
cwd=$(jq -r '.cwd // empty' <<<"$input")
[[ $teammate == eng-* ]] || exit 0
root=$(git -C "${cwd:-.}" rev-parse --show-toplevel 2>/dev/null) || exit 0
gate="$root/.claude/team-gate.sh"
[[ -f $gate ]] || exit 0
# In worktree mode the engineer works on branch team/<name> in its own worktree:
# run the gate there.
dir=$root
wt=$(git -C "$root" worktree list --porcelain |
  awk -v b="refs/heads/team/$teammate" '/^worktree /{w=substr($0,10)} $0=="branch " b {print w}')
[[ -n $wt ]] && dir=$wt
if out=$(cd "$dir" && bash "$gate" 2>&1); then
  exit 0
fi
{
  echo "Quality gate failed in $dir (.claude/team-gate.sh). The task stays open."
  echo "Fix it, rerun the gate, then mark the task completed again. Last lines:"
  tail -n 40 <<<"$out"
} >&2
exit 2
