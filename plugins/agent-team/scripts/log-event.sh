#!/usr/bin/env bash
# Appends one line per team event (task created or completed, teammate idle) to
# ~/.claude/agent-team/log.jsonl so the planner can report time per teammate.
# Reads the hook's JSON on stdin, or takes it as $1 when called from another script.
set -uo pipefail
input=${1:-$(cat)}
dir="$HOME/.claude/agent-team"
mkdir -p "$dir" 2>/dev/null || exit 0
jq -c --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{
    ts: $ts,
    event: .hook_event_name,
    cwd: .cwd,
    session: .session_id,
    teammate: (.teammate_name // "lead"),
    task_id: (.task_id // null),
    task: (.task_subject // null)
  }' <<<"$input" >>"$dir/log.jsonl" 2>/dev/null
exit 0
