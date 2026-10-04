---
name: ship-task
description: Push the current task branch, open a PR, watch checks, squash-merge, sync the default branch and clean up.
argument-hint: "<conventional-commit PR title>"
disable-model-invocation: true
---

Ship the reviewed work on the current branch. `$ARGUMENTS` is the PR title in conventional-commit form (e.g. `feat(settings): grouped Settings list and a pushed Profile screen`); if empty, derive it from the branch's commits.

`<base>` below is the repo's default branch: `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`. `<branch>` is the current branch.

This merges into the default branch, so when something unexpected happens, stop and report rather than improvising — a wrong merge is much harder to undo than a paused one.

0. **Check the starting state.** Stop and report if `gh auth status` fails, if there is no `origin` remote, if `<branch>` is `<base>` or HEAD is detached, if `git status --porcelain` shows uncommitted changes, or if `git fetch origin && git rev-list --count origin/<base>..HEAD` is 0. Note whether this is a linked worktree (the two lines of `git rev-parse --path-format=absolute --git-dir --git-common-dir` differ; without `--path-format=absolute` they differ in any subdirectory too); step 5 needs it. Done when the branch is clean and has commits to ship.
1. **Preflight.** From the repo root run the preflight command named in `CLAUDE.md` or `AGENTS.md`, if there is one. Otherwise run each of the `lint`, `typecheck`, `test` and `build` scripts that exist in `package.json`, in that order, with the package manager its lockfile implies (`pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, `bun.lock`/`bun.lockb` → bun, else npm). With no `package.json`, use the project's own equivalents if they are obvious (a `Makefile` `check`/`test` target, `cargo test`, `go test ./...`, `pytest`). If there is nothing to run, say so and continue. Stop and report if anything fails. Done when every command passes.
2. **Rebase.** `git rebase origin/<base>`. If a conflict is mechanical (imports, lockfiles, adjacent additions), resolve it, `git add` the files and `git rebase --continue`; if resolving it means choosing between two behaviours, `git rebase --abort` and ask. After a rebase that moved the branch, re-run step 1. Done when the branch sits on `origin/<base>` and step 1 is green.
3. **Push and open the PR.** `git push --force-with-lease -u origin HEAD` (the rebase rewrote history, so a plain push is rejected if the branch was pushed before; `--force-with-lease` still refuses to clobber commits someone else pushed). If `gh pr list --head <branch> --state open --json url -q '.[0].url'` prints a URL, that PR is already open: reuse it and update its title with `gh pr edit --title`. Otherwise run `gh pr create --base <base> --title "<title>" --body-file -` with this body on stdin:

   ```
   ## Summary
   <what changed, grouped by area, 3–8 bullets>

   ## Test plan
   - [x] <each preflight command and its result, with the test count>
   - [x] <any other checks run (e.g. e2e specs) and their result>

   🤖 Generated with [Claude Code](https://claude.com/claude-code)
   ```
   Keep the attribution line unless the project's `CLAUDE.md` or `AGENTS.md` asks for a different one. Done when you have the PR URL.
4. **Watch checks.** `gh pr checks --watch --interval 10` (it blocks until nothing is pending; give the command a ~10 min timeout). If it reports no checks, move on. If it is still pending at the timeout, stop and report which checks are stuck. If a check fails because of the code, read its log (`gh run view <run-id> --log-failed`), fix, commit, push and watch again. If it fails for an outside reason (e.g. a hosting setting or missing secret), stop and ask. Done when every check passes.
5. **Merge and sync.**
   - Normal checkout: `gh pr merge --squash --delete-branch`, then `git checkout <base> && git pull --ff-only origin <base> && git fetch --prune`, and `git branch -D <branch>` if it still exists.
   - Linked worktree: `gh pr merge --squash` without `--delete-branch` (it would try to check out `<base>`, which the main worktree already holds), then `git push origin --delete <branch>`. Move to the main worktree (the first `worktree` line of `git worktree list --porcelain`) and run `git worktree remove <worktree-path>` (if it refuses because of untracked files, list them and ask rather than adding `--force`; they may be someone's unsaved work), `git branch -D <branch>`, then `git checkout <base> && git pull --ff-only origin <base> && git fetch --prune` there.

   If the merge is refused (required reviews, branch protection, merge queue), stop and report the reason; don't bypass it with `--admin`. Done when local `<base>` equals `origin/<base>` and the branch is gone locally and on the remote.
6. **Report** the PR URL, the merge commit (`gh pr view <url> --json mergeCommit -q .mergeCommit.oid`), and the check results in two lines.
