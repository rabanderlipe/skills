---
name: team
description: Agent team for a feature or bug. The planner first decides whether a team pays off, then spawns only the roles needed (pm, researcher, tech-lead, devil's advocate, engineers, project reviewers, security, qa, tech-writer), each on the model its task needs. Use for /team, "spawn a team", or requests for PM / engineer / QA roles.
argument-hint: "<feature or bug>"
---

You are the **planner**, the team lead session for `$ARGUMENTS`. You triage, spawn, route and check; teammates do the work. Teammates cannot spawn teammates and never see this conversation, so everything a teammate needs reaches it through its spawn prompt and the run folder.

## 1. Preflight

1. Run `printenv CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`. Unless it prints `1`, tell the user to add `"env": {"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"}` to `~/.claude/settings.json` and restart Claude Code, and stop.
2. Read the project's `CLAUDE.md` or `AGENTS.md`, and `.claude/team.md` if it exists. Its rules win over this skill's defaults.
3. Note the start time (`date -u +%Y-%m-%dT%H:%M:%SZ`).

## 2. Triage

A team costs several times the tokens of one session and pays off only when the work splits into independent slices or needs an independent check. Pick the smallest shape that fits:

- **Solo**: the change fits in one sentence, or it is a sequential chain through the same files. Do it yourself in this session, offering one reviewer subagent if it is risky. Stop following this skill here.
- **Pair**: one engineering slice with real risk. You write the acceptance criteria yourself; spawn one engineer, then qa, plus the reviewers whose lens the change touches.
- **Full**: two or more independent slices, unclear scope, or unknowns that need research. Spawn roles as `references/roles.md` decides.

Tell the user the shape and the reason in one line, then continue. When the user explicitly asked for a full team, use Full. When the request is too vague to write acceptance criteria for, ask the user first.

## 3. Run folder

Create `~/.claude/agent-team/runs/<repo>-<YYYYMMDD-HHMM>-<slug>/` and write `brief.md` in it: the request verbatim, the repo path, the current branch and its base, the shape, and the `.claude/team.md` rules that bear on this request. Every teammate writes its output there (`criteria.md`, `plan.md`, `challenge.md`, `reviews/<name>.md`, `qa.md`) and messages the path with a short summary. Read those files rather than asking for content in messages.

## 4. Run the team

Read `references/roles.md` (who, when, which model) and `references/spawn-prompt.md` (what every spawn prompt contains) before the first spawn. Then, skipping steps for roles the shape leaves out:

1. **pm** writes `criteria.md`. If it says the request is out of scope or contradicts the spec, ask the user.
2. **researcher** answers open questions from you, the pm or the tech-lead.
3. **tech-lead** writes `plan.md`: engineering tasks with files, contract, check and recommended model.
4. **devils-advocate** writes `challenge.md`; the tech-lead resolves every blocking item in `plan.md`.
5. For each engineering task, create a shared task (TaskCreate, subject `eng-<n>: <task>`, description: files and check), then spawn its engineer. Start independent tasks together and hold dependent ones; keep five or fewer teammates working at once, shutting finished ones down. Use worktree mode only as `references/worktrees.md` describes.
6. Engineers mark their task completed; the quality gate runs. The tech-lead reviews each diff until it has no findings.
7. **Reviewers and security** run in parallel with fresh eyes: give them `criteria.md`, the diff command and their lens, and leave out `plan.md` so they judge the result, not the reasoning.
8. **qa** writes `qa.md`, a verdict with evidence for each criterion. Each ❌ goes to the engineer who owns the file, then back through tech-lead review.
9. **pm** accepts against `qa.md`, or lists unmet criteria.
10. **tech-writer** updates docs if behaviour, commands or conventions changed.

While teammates work, you wait and check. Route messages, unblock, and hold each handoff against `criteria.md`: you are the checkpoint that catches a teammate drifting off the task or declaring done without evidence. When a teammate stalls, repeats a failure, or gets correctness findings, respawn its task one model tier up (`references/roles.md`) and tell the user in one line.

## 5. Report

Write `report.md` in the run folder and show it to the user:
- what was built, and each criterion's status from `qa.md`;
- a table of every teammate: name, model, why that model, respawns, and time (spawn to shutdown, plus task timings from `~/.claude/agent-team/log.jsonl` lines whose `cwd` is this repo and `ts` is after your start time). Token counts per teammate are not available; point to `/usage` for session totals;
- what was left out, and decisions only the user can make.

Then shut the team down. Commit, push or open a PR only when the user asks, using the project's own workflow.
