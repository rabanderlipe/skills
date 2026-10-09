# Spawn prompts

A teammate starts with its role definition, the project's CLAUDE.md and nothing from this conversation. Its spawn prompt is the whole brief, so a vague one gets misread work and duplicated effort. Every spawn prompt contains:

1. **Identity**: name, agent type, model. `Spawn teammate eng-2 using the agent-team:engineer agent type on model sonnet.`
2. **Run folder**: its absolute path, and which files there to read first.
3. **Objective**: one sentence on the outcome, in user terms.
4. **Scope**: the files it owns, and what is explicitly out of scope.
5. **Contract** (engineers): signatures, schema or API shape, error cases it must honour.
6. **Check**: the command or observation that proves the work, and the evidence to report.
7. **Output**: the file to write in the run folder and who to message with its path.
8. **Mode flags** when they apply: `worktree mode`, or the shared task id it owns.

Keep it to what this teammate needs; every line costs context for its whole life.

Example:

```
Spawn teammate eng-1 using the agent-team:engineer agent type on model opus.
Run folder: /Users/me/.claude/agent-team/runs/shop-20261009-1430-refunds/. Read brief.md, criteria.md and plan.md (task 1).
Objective: partial refunds are recorded and reduce the order balance.
Files you own: db/migrations/<new>.sql, db/tests/refunds.test.sql. Out of scope: UI, the API adapter.
Contract: rpc refund_order(order_id uuid, amount_cents bigint) returns refunds; raises 'over_refund' when amount exceeds the paid balance; owner role only.
Check: `pnpm db:test` passes, including new cases for over_refund and a non-owner caller.
Output: you own shared task 3; mark it completed when the check passes, then message tech-lead with the files changed and the test output.
```
