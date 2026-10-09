# skills

Claude Code plugins by [@rabanderlipe](https://github.com/rabanderlipe).

```
/plugin marketplace add rabanderlipe/skills
/plugin install ship-task@rabanderlipe
/plugin install codebase-cleanup@rabanderlipe
/plugin install agent-team@rabanderlipe
```

## ship-task

`/ship-task:ship-task "<conventional-commit PR title>"` — preflight, rebase on the default branch, push, open a PR, watch checks, squash-merge, sync and clean up. Needs `gh` signed in.

Preflight runs the command your `CLAUDE.md` or `AGENTS.md` names (e.g. `Preflight: make check`); otherwise the `lint`, `typecheck`, `test` and `build` scripts that exist in `package.json`, or the project's obvious equivalents (`make check`, `cargo test`, `go test ./...`, `pytest`). It stops instead of improvising when something unexpected happens: rebase conflicts that need a judgement call, failing checks it can't fix, or a merge blocked by branch protection. If the repo has a PR template, the PR body fills it in; otherwise it uses a Summary / Test plan body.

## codebase-cleanup

A repo-wide tech-debt audit that loads automatically on requests like "clean this repo up", "what can we delete?", "find unused deps" or a long maintainability-review prompt. You can also run it directly with `/codebase-cleanup:codebase-cleanup`, optionally naming a package or directory. It has two phases with a stop in between:

1. **Audit** (read-only): reads your `CLAUDE.md`/`AGENTS.md`, contributing guide and design docs, runs dead-code tools (`knip`, `vulture`, `staticcheck`, …) and verifies every hit by grep and reading. You get a short tiered report: bugs first, then what's safe to delete, what's a product call and what it deliberately kept, with the risk for each item and a suggested PR sequence. Your working tree, branches, git config and hooks are left exactly as they were, uncommitted work included. It won't run installs that trigger lifecycle scripts or test targets that reset a database.
2. **Execute** (only for the items you approve): one branch and one PR per concern, branched from the default branch. If you have uncommitted work, it uses a separate worktree. Each change is linted, type-checked, tested and built, and UI changes are screenshotted. It pushes the branches and opens PRs with `gh`, then leaves them open for you to review. **It never merges.** Without `gh` it pushes the branches and hands you the list. Without a remote it leaves local branches.

It works with any language. The tool and framework examples lean JS/TS but adapt to Python, Go, Rust and so on. Evals and trap-filled fixture repos are in [`evals/codebase-cleanup`](evals/codebase-cleanup).

## License

[MIT](LICENSE)

## agent-team

`/agent-team:team "<feature or bug>"` runs a planner-led agent team. Your session is the planner. It spawns a `pm`, a `lead-engineer`, one `engineer` per task and a `qa` as teammates, which share a task list and message each other by name. The flow is PM acceptance criteria, then the lead engineer's plan split into tasks that touch separate files, then engineers building test-first, lead review, QA with evidence for each criterion, and PM sign-off. It never commits; you ship when you're ready.

The planner chooses a model for each teammate from what its task needs. Opus handles architecture, security, migrations and unexplained bugs; Sonnet handles well-specified implementation, QA and scoping; Haiku handles mechanical edits. The lead engineer recommends a model for each engineering task. A teammate that stalls or fails review is respawned one tier up.

Needs agent teams turned on, which is experimental: add `"env": {"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"}` to `~/.claude/settings.json` and restart Claude Code.

Every role reads your `CLAUDE.md`/`AGENTS.md`. For project-specific rules (spec files, test commands, review checklists, skills per kind of work, model overrides), copy [`team.example.md`](plugins/agent-team/team.example.md) to `.claude/team.md` in the project.
