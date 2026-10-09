#!/usr/bin/env bash
# Real end-to-end stress test of the agent-team plugin: fresh fixtures, one interactive
# Claude Code session per scenario (in parallel, auto permission mode), then checks.
# Usage: ./run-all.sh <out-dir> [scenario ...]   (default: all scenarios in scenarios.json)
# Costs real API usage: Full-team scenarios run several opus teammates.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
out=${1:?usage: run-all.sh <out-dir> [scenario ...]}; shift
plugin=$(cd "$here/../../plugins/agent-team" && pwd)
scenarios=("$@")
if (( ${#scenarios[@]} == 0 )); then
  while IFS= read -r s; do scenarios+=("$s"); done < <(jq -r 'keys[]' "$here/scenarios.json")
fi
"$here/make-fixtures.sh" "$out" "${scenarios[@]}" >/dev/null
mkdir -p "$out/results"
for s in "${scenarios[@]}"; do
  "$here/drive.py" "$s" "$out/tally-$s" "$plugin" "$out/results" > "$out/results/$s.drive.log" 2>&1 &
  sleep 20  # stagger startups
done
wait
for s in "${scenarios[@]}"; do "$here/check.py" "$s" "$out/tally-$s" "$out/results"; done | tee "$out/results/summary.txt"
