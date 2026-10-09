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

`/agent-team:team "<feature or bug>"` runs a planner-led agent team. Your session is the **planner**. It first decides whether a team pays off at all. Teams cost several times the tokens of one session, so a one-line fix runs **Solo** in your session. A single risky task gets a **Pair**: one engineer plus QA and reviewers. Independent slices or open unknowns get the **Full** team:

- **pm**: observable acceptance criteria checked against your spec, and sign-off against QA's evidence.
- **researcher**: cited answers from primary sources in `docs/research/`, using `/mattpocock-skills:research` when it's installed.
- **tech-lead**: a plan of tasks that touch separate files, each with a contract, a check and a recommended model. It also reviews every diff.
- **devils-advocate**: tries to break the plan before any code exists, using `/mattpocock-skills:grilling` when it's installed.
- **engineer** (one per task): builds test-first and reports evidence.
- **your project's reviewers**, plus **security** for auth, permissions, secrets or input: fresh reviewers that judge the diff against the criteria, not the plan.
- **qa**: a ✅/❌ verdict per criterion, backed by commands it ran itself.
- **tech-writer**: updates docs after sign-off.

Teammates write their output to a run folder (`~/.claude/agent-team/runs/…`) and pass file paths instead of pasting content into messages. The planner waits and checks each handoff against the criteria instead of writing code. The planner names a model for every teammate based on its task: Opus for architecture, security, migrations, money or date logic and adversarial review; Sonnet for well-specified building, QA and scoping; Haiku for mechanical edits and single lookups. A teammate that stalls or fails review is respawned one tier up. The final report has a table of every teammate with its model, the reason for it, respawns and time taken. Token counts per teammate aren't available, so use `/usage` for totals. It never commits; you ship when you're ready.

Hooks enforce a quality gate. When an engineer marks its task done, your project's `.claude/team-gate.sh` runs, and a failure keeps the task open and sends the output back to the engineer. A teammate's first idle sends it back once to check its "done" condition. When tasks can't be split across separate files, **worktree mode** gives each engineer its own worktree and `team/<name>` branch, and the planner merges them after review.

Setup:
- Turn on agent teams, which are experimental: add `"env": {"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"}` to `~/.claude/settings.json` and restart Claude Code.
- Optional: copy [`team.example.md`](plugins/agent-team/team.example.md) to `.claude/team.md` for project rules (sources of truth, commands, reviewers, skills, what QA checks, worktree safety, model overrides), and [`team-gate.example.sh`](plugins/agent-team/team-gate.example.sh) to `.claude/team-gate.sh`.
- Optional: teammates waiting on each other lose their prompt cache after 5 minutes. Setting `"subagentPromptCacheTtl": "1h"` in settings keeps it warm between handoffs.
