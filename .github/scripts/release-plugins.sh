#!/usr/bin/env bash
# For each plugin whose plugin.json version has no <plugin>@v<version> tag yet, creates that
# tag and a GitHub release on <target> (default HEAD), with the plugin's commits since its
# previous release as notes. Needs gh signed in (GH_TOKEN in CI) and full history with tags.
# Usage: release-plugins.sh [target-commit]
set -euo pipefail
target=$(git rev-parse "${1:-HEAD}")
for manifest in plugins/*/.claude-plugin/plugin.json; do
  p=$(git show "$target:$manifest" 2>/dev/null | jq -r .name) || continue
  [[ -n $p && $p != null ]] || continue
  v=$(git show "$target:$manifest" | jq -r .version)
  tag="$p@v$v"
  if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
    echo "$tag exists, skipping"
    continue
  fi
  prev=$(git tag --list "$p@v*" --merged "$target" --sort=-version:refname | head -1)
  range=${prev:+$prev..}$target
  notes=$(git log --format='- %s (%h)' "$range" -- "plugins/$p")
  [[ -n $notes ]] || notes="- No changes under plugins/$p since ${prev:-the start}."
  if [[ -n $prev ]]; then notes+=$'\n\n'"Changes since $prev."; fi
  gh release create "$tag" --target "$target" --title "$p v$v" --notes "$notes" --latest=false
  echo "released $tag"
done
