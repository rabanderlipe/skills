#!/usr/bin/env bash
# Creates or updates the PR labels used by .github/labeler.yml with their colors and
# descriptions. Run after adding a label there: .github/scripts/sync-labels.sh
set -euo pipefail
while IFS='|' read -r name color desc; do
  gh label create "$name" --color "$color" --description "$desc" --force
done <<'LABELS'
plugin:ship-task|7057FF|Changes to the ship-task plugin
plugin:codebase-cleanup|E99695|Changes to the codebase-cleanup plugin
plugin:agent-team|0E8A16|Changes to the agent-team plugin
marketplace|FBCA04|Marketplace manifest (.claude-plugin/)
evals|0E8A16|Eval suites and fixtures
claude-config|D97706|Claude Code setup: .claude/ and CLAUDE.md
ci/cd|6E7781|Workflows, GitHub config and git hooks
documentation|0075CA|README and LICENSE
LABELS
