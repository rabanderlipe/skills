#!/usr/bin/env bash
# TaskCompleted hook (sessions with the Task tools). When an engineer (teammate eng-*)
# marks a task completed, runs the quality gate and refuses the completion (exit 2,
# output fed back) if it fails.
set -uo pipefail
input=$(cat)
here=$(dirname "$0")
"$here/log-event.sh" "$input"
teammate=$(jq -r '.teammate_name // empty' <<<"$input")
cwd=$(jq -r '.cwd // empty' <<<"$input")
[[ $teammate == eng-* ]] || exit 0
out=$("$here/run-gate.sh" "${cwd:-.}" "$teammate") && exit 0
{
  echo "$out"
  echo "The task stays open. Fix the failures, rerun the gate, then mark the task completed again."
} >&2
exit 2
