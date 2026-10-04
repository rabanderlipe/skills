#!/usr/bin/env bash
# PostToolUse: after an edit to a manifest or SKILL.md, run `claude plugin validate`
# on the marketplace and the touched plugin. Exit 2 feeds the failure back to Claude.
set -uo pipefail
f=$(jq -r '.tool_response.filePath // .tool_input.file_path // empty')
case "$f" in
  */.claude-plugin/*.json|*/SKILL.md) ;;
  *) exit 0 ;;
esac
root=${CLAUDE_PROJECT_DIR:-$(git -C "$(dirname "$f")" rev-parse --show-toplevel)}
targets=("$root")
if [[ $f =~ ^$root/plugins/([^/]+)/ ]]; then targets+=("$root/plugins/${BASH_REMATCH[1]}"); fi
status=0
for t in "${targets[@]}"; do
  if ! out=$(claude plugin validate "$t" 2>&1); then echo "$out" >&2; status=2; fi
done
exit $status
