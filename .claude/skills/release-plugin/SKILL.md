---
name: release-plugin
description: Bump a plugin's version and sync its description across plugin.json, marketplace.json and README.
argument-hint: "<plugin> <patch|minor|major> [new one-line description]"
disable-model-invocation: true
---

Release `$ARGUMENTS`: the first word is the plugin name (a directory under `plugins/`), the second is the bump level, and anything after that is a new one-line description. Stop and ask if the plugin doesn't exist or the bump level is missing.

1. **Read the current state.** `plugins/<p>/.claude-plugin/plugin.json`, the plugin's entry in `.claude-plugin/marketplace.json`, its `## <p>` section in `README.md`, and `git diff HEAD -- plugins/<p>` plus `git log --oneline -10 -- plugins/<p>` to see what changed since the last release.
2. **Bump the version** in `plugin.json` by the requested level. If the working tree already has the version changed from HEAD, ask whether to keep it or bump again rather than bumping twice.
3. **Sync the description.** If a new description was given, write it to both `plugin.json` and the marketplace entry. If not, make the marketplace entry match `plugin.json`. The two strings must be identical.
4. **Check the README section** against the changes from step 1. If behavior, arguments or install steps changed, update that section to match. Leave it alone otherwise. It is longer prose, not a copy of the description.
5. **Validate.** Run `claude plugin validate .` and `claude plugin validate plugins/<p>`. Fix any failure.
6. **Report** the old version → new version, the files changed, and a suggested conventional-commit title (`feat(<p>): …` for minor, `fix(<p>): …` for patch, with `!` for major). Don't commit or push; the user ships with `/ship-task:ship-task`.
