# Worktree mode

Default: engineers share the checkout and own disjoint files. Use worktree mode only when the tech-lead says tasks cannot be file-disjoint, or `.claude/team.md` turns it on.

- Before turning it on, read the Worktrees section of `.claude/team.md`. If the project shares one local database or service across worktrees and two tasks change its schema, keep those tasks with one engineer instead, or warn the user.
- Put `worktree mode` in each engineer's spawn prompt. The engineer creates `../<repo>-<name>` on branch `team/<name>`, works and commits only there, and reports the branch.
- The quality gate runs inside that worktree.
- The tech-lead reviews with `git diff <base>...team/<name>`.
- Before qa, bring each branch back in dependency order with `git merge --squash team/<name>` followed by `git reset -q` (its changes land in the working tree uncommitted, so nothing is committed without the user). Resolve conflicts, asking the user when one needs a product or design call. Run the gate once on the result, then `git worktree remove ../<repo>-<name>` and `git branch -D team/<name>` for each. This is part of every worktree run, not a step that waits for the user.
