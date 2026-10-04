Claude Code plugin marketplace. Each plugin lives in `plugins/<name>/` and is listed in `.claude-plugin/marketplace.json`.

Preflight: claude plugin validate . && for p in plugins/*; do claude plugin validate "$p" || exit 1; done

- A plugin's one-line description is stored twice and must match exactly: `plugins/<p>/.claude-plugin/plugin.json` and its entry in `.claude-plugin/marketplace.json`. Its `README.md` section is longer prose; update it when behavior changes.
- Bump `version` in `plugins/<p>/.claude-plugin/plugin.json` (semver) whenever that plugin's skills change behavior. Installed copies only update when the version changes.
- `/release-plugin <p> <patch|minor|major>` does the bump and sync.
- Evals for a plugin live in `evals/<p>/` (skill-creator `evals.json` format). The `eval-runner` agent runs them.
- PR descriptions follow `.github/pull_request_template.md`: fill every section and tick only the boxes that are true.
- `.claude/hooks/` validates manifests after edits and checks description/version sync before stopping.
