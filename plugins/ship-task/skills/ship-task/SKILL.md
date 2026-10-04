---
name: ship-task
description: Push the current task branch, open a PR, watch checks, squash-merge, sync the default branch and clean up.
disable-model-invocation: true
---

Ship the reviewed work on the current branch. `$ARGUMENTS` is the PR title in conventional-commit form (e.g. `feat(settings): grouped Settings list and a pushed Profile screen`); if empty, derive it from the branch's commits.

`<base>` below is the repo's default branch: `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`.

1. **Preflight.** From the repo root run the preflight command named in `CLAUDE.md` or `AGENTS.md`, if there is one. Otherwise run each of the `lint`, `typecheck`, `test` and `build` scripts that exist in `package.json`, in that order, with the package manager its lockfile implies (`pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, `bun.lock`/`bun.lockb` → bun, else npm). If neither exists, say so and continue. Stop and report if anything fails. Done when every command passes.
2. **Rebase.** `git fetch origin && git rebase origin/<base>`. If conflicts appear, resolve them keeping both sides' additions, then re-run step 1. Done when the branch sits on `origin/<base>` and step 1 is green.
3. **Push and open the PR.** `git push -u origin HEAD`, then `gh pr create --base <base>` with this body:

   ```
   ## Summary
   <what changed, grouped by area, 3–8 bullets>

   ## Test plan
   - [x] <each preflight command and its result, with the test count>
   - [x] <any other checks run (e.g. e2e specs) and their result>

   🤖 Generated with [Claude Code](https://claude.com/claude-code)
   ```
   Done when `gh` prints the PR URL.
4. **Watch checks.** Poll `gh pr checks` every 10s (max ~5 min) until nothing is pending. If a check fails because of the code, fix it, push, and watch again. If it fails for an outside reason (e.g. a hosting setting), stop and ask. If the repo has no checks, move on. Done when every check passes.
5. **Merge and sync.** `gh pr merge --squash --delete-branch`, then `git checkout <base> && git pull --ff-only origin <base> && git fetch --prune`. If the branch lived in a worktree, `git worktree remove <path>` and `git branch -D <branch>`. Done when local `<base>` equals `origin/<base>` and the branch is gone.
6. **Report** the PR URL, the merge commit, and the check results in two lines.
