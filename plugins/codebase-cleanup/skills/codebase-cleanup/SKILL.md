---
name: codebase-cleanup
description: Repo-wide technical-debt audit and cleanup — find dead code, duplication, legacy or abandoned leftovers, unused dependencies, redundant queries and stale docs, verify every finding, then (only after the user approves) ship the fixes as small, convention-following pull requests. Use when the user wants an open-ended code-quality, maintainability or tech-debt review of a repo, package or directory — "clean this repo up", "simplify the codebase", "what can we delete", "anything abandoned in services/?", "find unused deps", or a long review prompt listing dead code / duplicate logic / redundant API calls — even if they only want the report. Not when the user already names the exact change (one file, helper, rename or flag), and not for reviewing a diff or PR, debugging, or security review.
---

# Codebase cleanup

Two phases with a stop in between:

1. **Audit** — find candidates, verify each one, write a tiered report and a PR plan. Read-only.
2. **Execute** — only after the user says go: one branch and one pull request per concern, each verified before it is opened. PRs are left open for a human to review and merge — never merge them, even when CI is green, unless the user explicitly overrides this in the current conversation.

The stop matters because the audit is cheap to redo and the execution is not: deleting a route or a dependency is a product decision as often as a technical one, and the user is the one who knows whether a "dead" URL is bookmarked somewhere or a "unused" library was kept on purpose.

## Phase 1 — Audit

The audit is read-only in the strict sense: when it ends, the repo, its git config and its hooks are exactly as you found them. The user should be able to run it on a repo with uncommitted work and lose nothing.

- **No edits to tracked files, even temporary ones.** To test a hypothesis — does this lint suppression matter, what is this ignore list hiding — copy the file(s) to a scratch directory outside the repo and experiment there. "I changed it and restored it with `git checkout`" is still a change: it can clobber uncommitted work and races with anything else watching the tree.
- **Prefer tools that need no install** (`pnpm dlx`, `npx`, a globally available binary). If an install is genuinely needed for an accurate result, use `--ignore-scripts` (install hooks such as husky's `prepare` rewrite `core.hooksPath`), keep it to gitignored paths, and say in the report what you installed. If even that isn't possible, skip the check and say so — a missing data point is better than a side effect. Without installed dependencies, dead-code tools misreport (knip flags every framework package as unused); discount those hits and say the tool run was partial.

### 1. Learn the repo's rules before judging it

Read, if present: `CLAUDE.md` / `AGENTS.md`, `CONTRIBUTING.md`, the PR template (`.github/pull_request_template.md`), CI workflows (what does CI run, what do convention checks enforce), and any design/decision records (TRD, ADRs, `docs/`). Note:

- the package manager and the lint / type-check / test / build commands
- branch-name, commit-message and PR-title conventions (and whether CI checks them)
- **recorded decisions** — a design doc that says "keep X" or "Y exists because Z" outranks your "nothing imports X". Cross-check every deletion against these; when code and doc disagree, surface it rather than silently picking one.

In a monorepo or a very large repo, confirm the scope (which packages) with the user before scanning, run tools per workspace, and report per package. The examples below lean JS/Next; apply the same idea to the repo's own stack (Django `urls.py`, Rails routes, Go `embed` directives, static dirs).

Run the baseline (lint, types, tests) once, if it can run without installing anything and only writes gitignored output (compare `git status --porcelain` before and after; skip anything that seeds, migrates or resets a database), so you can later tell pre-existing failures from ones you caused. If something fails for a reason outside the repo (an untracked local file, a missing env var), say so rather than "fixing" it.

### 2. Find candidates with tools, then with reading

Tools give breadth; reading gives the findings tools can't see. Use both.

- **Unused files / exports / dependencies:** for JS/TS, `knip` (via the repo's `dlx`/`npx`) in normal mode *and* with `--production` — the second catches exports that only tests use. Other ecosystems: `vulture` (Python), `deadcode`/`staticcheck` (Go), `cargo udeps`/`cargo machete` (Rust), `ts-prune`, or the compiler's own unused warnings.
- **Unreachable routes/pages:** for each route, grep for links to it (`href`, `router.push`, `redirect`, manifest shortcuts, emails, tests). A route with no inbound link is a candidate, not a verdict.
- **Unused styles/tokens/icons/assets:** keys defined in a style object or token file and never referenced; icons registered in a map but never named; files in `public/` never referenced. A short script over the tracked files beats eyeballing.
- **Duplication:** the same helper, constant table, literal default (a timezone, a currency, a magic number), lookup expression or form-field mapping written in several places; the same component re-implemented per file; two implementations of one side effect.
- **Redundant data access:** screens or forms that subscribe to a whole view model to read one record; the same query issued twice; a session/auth read immediately followed by a listener that delivers the same value.
- **Legacy leftovers:** styles or code from mockups/prototypes that nothing uses (a fake caret, a pinned focus state); comments that reference files, phases or behaviour that no longer exist; copy-pasted lint suppressions whose stated reason is wrong (test by removing them and re-running the linter on a copy that includes the lint config and tsconfig, or in a throwaway `git worktree add` outside the repo; if neither works, mark it unverified).
- **Stale docs:** agent-instruction files and design docs describing code that was deleted or finished. These cost the most per line, because every future session reads them.
- **Test-only code:** functions exercised only by tests. Decide whether each is *planned groundwork* (keep; docs will say so) or *a rule that should have been wired in* — the latter is often a real bug (e.g. a `canRefund` that enforces a 30-day window but no route calls).

### 3. Verify every candidate

Unverified findings are how cleanups break things. For each candidate, grep the whole repo — including scripts, CI, config, shell files, docs and tests — and read the hits.

Known false-positive shapes: files loaded by path from a build script (`readFile("scripts/x.js")`), configs referenced by a shell script (`--config vitest.integration.config.mts`), plugins loaded by a config file (`babel.config.js`), anything referenced by a framework convention (route files, `manifest.ts`, `loading.tsx`), and exports a test imports.

While verifying, look at the code around the finding. Duplicated code is where bugs hide: one copy gets fixed and the others don't. If a copy is visibly broken (a style that erases the border it just set, a check that never runs), record it as a bug — it usually earns its own `fix` PR, and it is the most valuable thing the audit finds.

### 4. Report

The reader has to act on this, so it must be scannable in a couple of minutes. Aim for roughly 150 lines; go longer only when the repo genuinely has that many consequential findings.

**Open with a summary of at most ~10 lines:** how many findings per tier, the bugs (one line each — they're the headline), the rough size of the win (lines/files/dependencies removable), and the decisions you need. Someone who reads only this should know whether to proceed.

**Spend words in proportion to consequence.** A bug or a risky deletion earns a paragraph; ten unused exports earn one line that lists them. Brevity never drops the risk, though: every table keeps a Risk column, and a terse "None" or "a bookmark breaks" is fine where a missing one is not. Don't restate the same evidence in the table, the tier text and the PR plan — say it once, where the item lives, and have the PR plan reference items by number.

Then group by what the user has to decide, not by the category list they gave you:

- **Tier 1 — delete now:** verified unused, no behaviour change.
- **Tier 2 — unreachable features:** routes/screens nothing links to; deleting is a product call.
- **Tier 3 — duplication**, noting any bug found inside it.
- **Tier 4 — redundant queries / calls.**
- **Tier 5 — decide, don't just delete:** test-only rules, recorded decisions the code contradicts, groundwork for planned features.
- **Tier 6 — stale docs.**

For each item: *what* (with `path:line`), *why it's unnecessary* (the evidence), *impact* of removing it, *risk* before deleting, and the *plan*. Tables work well for Tier 1. Also list what you checked and deliberately **kept**, with the reason — that is what makes an aggressive cleanup trustworthy.

End with a **suggested PR sequence** (see "One PR, one concern" below) and ask whether to proceed. Mention any decision you need from them (e.g. "delete these three routes?"). Then stop.

## Phase 2 — Execute (after approval)

Execute only the items the user approved; an approval of "tiers 1 and 3" is not an approval of the rest. If they asked up front for no stop ("just do it"), still show the report, then continue. If they asked only for a review, don't start Phase 2 unless invited.

Before the first branch: if the working tree has uncommitted changes, do the work in a `git worktree` (or ask) — never carry the user's edits into a cleanup branch. If there is no remote, commit on local branches and hand back the branch list; if there is a remote but `gh` can't open PRs on it (not installed, not signed in, not GitHub), push the branches and hand back the list so the user can open the PRs; if there is no CI, say that local verification is the only check.

### One PR, one concern

Split so that each PR's summary needs no "also". A typical sequence: each bug fix found → dead-code removal → each consolidation (by area) → query changes → docs. Bugs go early: they're the reason the cleanup pays for itself. If a later PR would use something a Tier-1 deletion removes (e.g. a hook the query PR revives), keep it out of the deletion.

Branch each PR from the default branch when it stands alone. Because nothing is merged, a PR that genuinely depends on an earlier one is **stacked**: branch from the earlier branch, open it with `--base <earlier-branch>`, and say so in the description. If the earlier PR changes, rebase the stacked branch onto it; once it merges, `git rebase --onto <default> <earlier-branch>` and retarget the PR. Keep stacks short; prefer ordering and independence.

### For each PR

1. `git fetch`, then branch from `origin/<default>` (or the earlier branch, if stacked) using the repo's convention: `git switch -c <name> origin/<default>`.
2. Make the change. Match surrounding style, comment density and idiom. When moving code, update the comments that described the old location.
3. Verify, in this order: formatter, linter, type-check, tests, production build. Framework caches can hold references to deleted files (Next.js: `.next/dev/types`) — clear them and rebuild before concluding a build is broken.
4. **Look at anything visible.** If the PR touches UI, run the production build locally and capture before/after screenshots at the app's target viewport, in each theme it supports (use the browser tooling the repo or environment already has, often Playwright; sign in with existing test credentials or seed data — don't run seeding yourself). This is not ceremony: in practice it's where "no visual change" turns out to be false, or where a suspected bug gets confirmed. If you can't capture something (a transient loading state), say so in the PR rather than implying you checked.
5. Commit with the repo's message convention; the body says *why*. Let pre-commit hooks run — if a hook fails on something outside your change, don't fold a fix into this PR or reach for `--no-verify`; stop, report it, and offer it as its own PR.
6. Push and open the PR with the repo's template filled in completely — no placeholder text left. Be specific about what was verified and how, what wasn't, the risk and the rollback. Tick only the checklist boxes that are true (leave "I have read every line" for the human).
7. Wait for CI (`gh pr checks <n> --watch`), if the repo has any. If it fails, fix on the same branch. When green, **leave it open** and move on.

### Things that must not happen (either phase)

- **Destructive local actions without asking** — e.g. test scripts that reset the local database, deleting stale branches or worktrees, rewriting files outside the repo. Mention them as follow-ups instead.
- **Merging.** Opening and verifying PRs is the job; merging is the reviewer's.
- **Silently overruling a recorded decision.** If you remove something a doc says to keep, update the doc in the same sequence and flag it in the PR's reviewer notes and in your summary.

## Final summary

When the sequence is done, report: a table of PR number → title → one-line outcome; which PRs are stacked on which; what was verified in a browser; what wasn't verified and why; decisions the user needs to make; and follow-ups you noticed but deliberately left out of scope.
