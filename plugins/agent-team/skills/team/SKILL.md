---
name: team
description: Run a planner-led agent team (pm, lead-engineer, engineers, qa) on a feature or bug, choosing each teammate's model by what its task needs. Use when the user says /team, "spawn a team", "use the agent team", or asks for PM / lead / engineer / QA roles to work on something.
argument-hint: "<feature or bug to build>"
---

Build `$ARGUMENTS` with an agent team. You are the team lead and planner. Teammates cannot spawn teammates, so you spawn every one and you choose each one's model.

## Before you start

1. Agent teams must be on. If `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is not `1` in your environment, stop and tell the user to add `"env": {"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"}` to `~/.claude/settings.json` and restart Claude Code.
2. Read the project's `CLAUDE.md` or `AGENTS.md`, and `.claude/team.md` if it exists. `.claude/team.md` holds this project's team rules: source-of-truth docs, test commands, review checklists, skills per kind of work, and model overrides. Its rules win over the defaults below.
3. If the request is unclear enough that the PM could not write acceptance criteria, ask the user first.

## Model policy

A model named in the spawn prompt overrides the `model:` in the agent definition, which is only a fallback. Name a model for every teammate you spawn. Choose per teammate, per task, by what the work needs, never by habit or role alone.

| Model | Use when the task is |
|---|---|
| `opus` | ambiguous or cross-cutting: architecture, security, permissions, schema or data migrations, concurrency, money or date math, a bug with no known cause, review of security-sensitive diffs |
| `sonnet` | well-specified implementation: a feature with a clear contract, UI built from a given design, tests for given criteria, QA runs, PM scoping against a spec |
| `haiku` | mechanical and fully specified: copy changes, renames, a one-line fix at a known location, re-running known suites and reporting output |

Defaults, which you adjust for the task in front of you:
- `pm`: sonnet. Use opus when the request conflicts with the spec or touches security or permissions.
- `lead-engineer`: opus.
- `engineer`: chosen per task from the lead engineer's plan.
- `qa`: sonnet. Use haiku when QA is only re-running known suites after a small fix.

If a teammate stalls, reports the same failure twice, or gets correctness findings in review, shut it down and respawn the task one tier up. Tell the user in one line.

## Flow

1. Spawn `pm` (the `agent-team:pm` agent type) with the request. Wait for scope and acceptance criteria. If the PM says it is out of scope or contradicts the spec, stop and ask the user.
2. Spawn `lead` (`agent-team:lead-engineer`) with the PM's task. Its plan lists, for each engineering task, the files (disjoint between tasks), dependencies, contract, tests and a recommended model with a reason.
3. Check each recommendation against the policy, then spawn one `agent-team:engineer` per task as `eng-1`, `eng-2`, …, naming its model, files, contract and tests in the spawn prompt. Start independent tasks in parallel and hold dependent ones until their blockers finish. Keep five or fewer teammates working at once.
4. Engineers report to `lead`, who reviews until there are no findings left.
5. Spawn `qa` (`agent-team:qa`) with the PM's acceptance criteria and the reviewed change. Each ❌ goes back to the engineer who owns the file, then through `lead` review again.
6. `pm` accepts, or lists the criteria that are still unmet.
7. Report to the user: what was built, which model each teammate ran and why, and the test results. Shut down the team. Commit, push or open a PR only when the user asks, using the project's own workflow.

Spawn prompt shape: `Spawn teammate eng-1 using the agent-team:engineer agent type on model sonnet. Task: … Files: … Contract: … Tests: …`
