---
name: team
description: Run a planner-led agent team (pm, researcher, lead-engineer, devil's advocate, engineers, reviewers, security, qa, tech-writer) on a feature or bug, choosing each teammate's model by what its task needs. Use when the user says /team, "spawn a team", "use the agent team", or asks for PM / lead / engineer / QA roles to work on something.
argument-hint: "<feature or bug to build>"
---

Build `$ARGUMENTS` with an agent team. You are the team lead and planner. Teammates cannot spawn teammates, so you spawn every one and choose each one's model. Agent types from this plugin are named `agent-team:<role>`.

## Before you start

1. Agent teams must be on. If `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is not `1` in your environment, stop and tell the user to add `"env": {"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"}` to `~/.claude/settings.json` and restart Claude Code.
2. Read the project's `CLAUDE.md` or `AGENTS.md`, and `.claude/team.md` if it exists. `.claude/team.md` holds this project's team rules: sources of truth, commands, reviewers, skills per kind of work, worktree policy and model overrides. Its rules win over the defaults below.
3. Note the time you start; you need it for the final report.
4. If the request is unclear enough that the PM could not write acceptance criteria, ask the user first.

## Roles

Spawn only the roles the task needs. Keep five or fewer teammates working at once; shut finished ones down before spawning more.

| Teammate name | Agent type | Spawn when | Default model |
|---|---|---|---|
| `pm` | `agent-team:pm` | always | sonnet; opus if the request conflicts with the spec or touches security or permissions |
| `researcher` | `agent-team:researcher` | the request or plan depends on something nobody on the team can confirm from the repo: an external API, a platform limit, a data source, a standard | sonnet; opus for contested or high-stakes questions |
| `lead` | `agent-team:lead-engineer` | always | opus |
| `advocate` | `agent-team:devils-advocate` | the plan has more than one engineering task, or touches data, permissions or money | opus |
| `eng-1`, `eng-2`, … | `agent-team:engineer` | one per task in the lead's plan | from the lead's plan |
| reviewer names from `.claude/team.md` | the project's agent types listed under Reviewers | the change touches what that reviewer covers | that agent's own model unless the task calls for more |
| `security` | `agent-team:security` | the change touches authentication, authorization, permissions, secrets, user input handling or data exposure | opus |
| `qa` | `agent-team:qa` | always | sonnet; haiku when only re-running known suites after a small fix |
| `writer` | `agent-team:tech-writer` | the change alters behaviour, commands, setup or conventions that docs describe | sonnet; haiku for a one-line doc fix |

## Model policy

A model named in the spawn prompt overrides the `model:` in the agent definition, which is only a fallback. Name a model for every teammate you spawn. Choose per teammate, per task, by what the work needs, never by habit or role alone.

| Model | Use when the task is |
|---|---|
| `opus` | ambiguous or cross-cutting: architecture, security, permissions, schema or data migrations, concurrency, money or date math, a bug with no known cause, review of security-sensitive diffs |
| `sonnet` | well-specified implementation: a feature with a clear contract, UI built from a given design, tests for given criteria, QA runs, PM scoping against a spec, research with clear sources |
| `haiku` | mechanical and fully specified: copy changes, renames, a one-line fix at a known location, re-running known suites and reporting output |

If a teammate stalls, reports the same failure twice, or gets correctness findings in review, shut it down and respawn the task one tier up. Tell the user in one line and count it for the final report.

## Flow

1. **Scope.** Spawn `pm` with the request. Wait for scope and acceptance criteria. If the PM says it is out of scope or contradicts the spec, stop and ask the user.
2. **Research** (if needed). Spawn `researcher` with the open questions from you or the PM. The PM and lead read its docs before going further.
3. **Plan.** Spawn `lead` with the PM's task and any research docs. Its plan lists, for each engineering task, the files (disjoint between tasks), dependencies, contract, tests and a recommended model with a reason.
4. **Challenge** (if needed). Spawn `advocate`; the lead sends it the plan and resolves every blocking issue before sending you the final plan.
5. **Decide worktree mode.** Use it when the lead says tasks cannot be file-disjoint, or `.claude/team.md` turns it on. Engineers in worktree mode each work on branch `team/<name>` in their own worktree; you merge those branches into the current branch, in dependency order, after review. Warn the user first if the project shares one local database or service across worktrees and tasks would change its schema.
6. **Build.** Check each model recommendation against the policy, then spawn one engineer per task, naming its model, files, contract, tests and, if on, `worktree mode` in the spawn prompt. Start independent tasks in parallel; hold dependent ones until their blockers finish. Engineers report to `lead`, who reviews until there are no findings left.
7. **Review.** Spawn the project reviewers and `security` that apply, in parallel, with the reviewed diff. Findings go to the owning engineer, then back through `lead`.
8. **Verify.** In worktree mode, merge the `team/*` branches first and remove the worktrees (`git worktree remove`). Spawn `qa` with the PM's acceptance criteria. Each ❌ goes back to the owning engineer, then through `lead` review again.
9. **Accept.** `pm` accepts, or lists the criteria that are still unmet.
10. **Document** (if needed). Spawn `writer` with the PM's task, the plan and the final diff.
11. **Report** to the user, then shut down the team:
    - what was built, and the test results;
    - a table of every teammate: name, model, why that model, respawns, and time (from spawn to shutdown, plus task timings from `~/.claude/agent-team/log.jsonl`: read the lines whose `cwd` is this repo and whose `ts` is after your start time). Say that per-teammate token counts are not available and point to `/usage` for session totals;
    - anything deliberately left out, and docs that need the owner's decision.

Commit, push or open a PR only when the user asks, using the project's own workflow.

## Quality gate

This plugin's hooks enforce two things:
- When an `eng-*` teammate marks a task completed, `.claude/team-gate.sh` in the project runs (in the engineer's worktree in worktree mode). If it fails, the task stays open and the engineer gets the output. Projects without that file are not gated; suggest the user add one (lint, typecheck, unit tests) if it is missing.
- The first time a teammate goes idle, it is sent back once to report or flag its blocker.

Spawn prompt shape: `Spawn teammate eng-1 using the agent-team:engineer agent type on model sonnet. Task: … Files: … Contract: … Tests: …`
