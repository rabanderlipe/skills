#!/usr/bin/env bash
# Checks that each plugin's description matches between plugin.json and marketplace.json,
# and that a plugin whose skills changed has a bumped version.
#
# As a Stop hook (no argument): compares against HEAD, blocks once, and on the retry
# (stop_hook_active) only warns.
# In CI (`check-plugin-sync.sh <base-ref>`): compares against <base-ref>, prints the
# problems and exits 1.
set -uo pipefail
base=${1:-}
if [[ -z $base ]]; then
  active=$(jq -r '.stop_hook_active // false')
fi
root=${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel)}
cd "$root" || exit 0
ref=${base:-HEAD}
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
  changed=$( { git diff "$ref" --name-only -- "$dir/skills"; git ls-files --others --exclude-standard -- "$dir/skills"; } 2>/dev/null)
  old=$(git show "$ref:$manifest" 2>/dev/null | jq -r .version 2>/dev/null)
  new=$(jq -r .version "$manifest")
  if [[ -n $changed && -n $old && $old == "$new" ]]; then
    problems+=("$p: skills changed but version is still $new in $manifest")
  fi
done
(( ${#problems[@]} == 0 )) && exit 0
msg=$(printf -- '- %s\n' "${problems[@]}")
if [[ -n $base ]]; then
  echo "Plugin sync check failed against $base:"$'\n'"$msg" >&2
  exit 1
elif [[ $active == true ]]; then
  jq -n --arg m "Plugin sync check:"$'\n'"$msg" '{systemMessage: $m}'
else
  jq -n --arg r "Plugin sync check failed. Fix these, or tell the user why they should stay:"$'\n'"$msg" '{decision: "block", reason: $r}'
fi
