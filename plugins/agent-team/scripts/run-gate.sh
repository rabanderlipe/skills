#!/usr/bin/env bash
# Runs the project's quality gate (.claude/team-gate.sh) for one engineer.
# Usage: run-gate.sh <cwd> <teammate>. Exit 0 when the gate passes or the project has
# none; otherwise exit 1 with the gate's last 40 lines on stdout. In worktree mode
# (a team/<teammate> branch checked out in a worktree) the gate runs in that worktree.
# The gate sees AGENT_TEAM_GATE=1, so it can add checks that only apply at handoff.
set -uo pipefail
cwd=$1 teammate=$2
root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0
gate="$root/.claude/team-gate.sh"
[[ -f $gate ]] || exit 0
dir=$root
wt=$(git -C "$root" worktree list --porcelain |
  awk -v b="refs/heads/team/$teammate" '/^worktree /{w=substr($0,10)} $0=="branch " b {print w}')
[[ -n $wt ]] && dir=$wt
if out=$(cd "$dir" && AGENT_TEAM_GATE=1 bash "$gate" 2>&1); then
  exit 0
fi
echo "Quality gate failed in $dir (.claude/team-gate.sh). Last lines:"
tail -n 40 <<<"$out"
exit 1
