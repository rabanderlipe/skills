#!/usr/bin/env bash
# Stop: before Claude finishes, check that each plugin's description matches between
# plugin.json and marketplace.json, and that a plugin whose skills changed since HEAD
# has a bumped version. Blocks once; on the retry (stop_hook_active) it only warns.
set -uo pipefail
active=$(jq -r '.stop_hook_active // false')
root=${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel)}
cd "$root" || exit 0
market=.claude-plugin/marketplace.json
problems=()
for manifest in plugins/*/.claude-plugin/plugin.json; do
  p=$(jq -r .name "$manifest")
  desc=$(jq -r .description "$manifest")
  mdesc=$(jq -r --arg p "$p" '.plugins[] | select(.name == $p) | .description' "$market")
  if [[ -z $mdesc ]]; then
    problems+=("$p is not listed in $market")
  elif [[ $desc != "$mdesc" ]]; then
    problems+=("$p: description differs between $manifest and $market")
  fi
  dir=plugins/$p
  changed=$( { git diff HEAD --name-only -- "$dir/skills"; git ls-files --others --exclude-standard -- "$dir/skills"; } 2>/dev/null)
  old=$(git show "HEAD:$manifest" 2>/dev/null | jq -r .version 2>/dev/null)
  new=$(jq -r .version "$manifest")
  if [[ -n $changed && -n $old && $old == "$new" ]]; then
    problems+=("$p: skills changed but version is still $new in $manifest")
  fi
done
(( ${#problems[@]} == 0 )) && exit 0
msg=$(printf -- '- %s\n' "${problems[@]}")
if [[ $active == true ]]; then
  jq -n --arg m "Plugin sync check:"$'\n'"$msg" '{systemMessage: $m}'
else
  jq -n --arg r "Plugin sync check failed. Fix these, or tell the user why they should stay:"$'\n'"$msg" '{decision: "block", reason: $r}'
fi
