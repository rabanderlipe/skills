#!/usr/bin/env bash
# Copy to .claude/team-gate.sh. The agent-team plugin runs it when an engineer marks a
# task completed, from the repo root (or the engineer's worktree). A non-zero exit keeps
# the task open and sends the output to the engineer. Keep it fast: lint, typecheck,
# unit tests. Leave slow suites to QA.
set -euo pipefail
npm run lint
npm run typecheck
npm test
