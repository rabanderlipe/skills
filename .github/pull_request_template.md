## Summary
<!-- What changed and why, 3–8 bullets. Name the plugin(s) touched. -->
-

## Testing
<!-- What you ran and what happened: claude plugin validate, eval results (e.g. "codebase-cleanup evals: 15/16, #3 fails on …"), manual runs of the skill. -->
-

Not tested:
<!-- Anything you couldn't check, or "nothing". -->

## Checklist
- [ ] `claude plugin validate .` and `claude plugin validate plugins/<p>` pass
- [ ] Version bumped in `plugins/<p>/.claude-plugin/plugin.json` if a skill's behavior changed
- [ ] Description identical in `plugin.json` and `.claude-plugin/marketplace.json`
- [ ] README section updated if commands, arguments or behavior changed
- [ ] Evals in `evals/<p>/` re-run, or updated to cover the change
