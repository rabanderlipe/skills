# Worktree mode

Default: engineers share the checkout and own disjoint files. Use worktree mode only when the tech-lead says tasks cannot be file-disjoint, or `.claude/team.md` turns it on.

- Before turning it on, read the Worktrees section of `.claude/team.md`. If the project shares one local database or service across worktrees and two tasks change its schema, keep those tasks with one engineer instead, or warn the user.
- Put `worktree mode` in each engineer's spawn prompt. The engineer creates `../<repo>-<name>` on branch `team/<name>`, works and commits only there, and reports the branch.
- The quality gate runs inside that worktree.
- The tech-lead reviews with `git diff <base>...team/<name>`.
- Before qa, merge the `team/*` branches into the current branch in dependency order, resolve conflicts (ask the user when a conflict needs a product or design call), run the gate once on the merged result, then `git worktree remove` each worktree and delete its branch.
