#!/usr/bin/env bash
# Builds the sandbox repos the agent-team stress test runs against.
# Usage: ./make-fixtures.sh <out-dir> [scenario ...]   (default: tally-{solo,full,gate,worktree,parked})
# Each repo is the same small Node ledger library ("tally", no dependencies) with a spec,
# a roadmap with parked items, .claude/team.md and .claude/team-gate.sh. Scenario tweaks:
#   gate      the gate also requires JSDoc on every export, a rule written nowhere else,
#             so the engineer's first completion is refused and must be fixed.
#   worktree  .claude/team.md turns worktree mode on.
set -euo pipefail
out=${1:?usage: make-fixtures.sh <out-dir> [scenario ...]}
shift
scenarios=("$@")
(( ${#scenarios[@]} )) || scenarios=(solo full gate worktree parked)
has() { [[ " ${scenarios[*]} " == *" $1 "* ]]; }
mkdir -p "$out" && cd "$out"
out=$(pwd)

base() {
  mkdir -p src test docs scripts .claude
  cat > package.json <<'EOF'
{
  "name": "tally",
  "private": true,
  "type": "module",
  "scripts": {
    "test": "node --test",
    "lint": "node scripts/lint.mjs"
  }
}
EOF
  cat > CLAUDE.md <<'EOF'
# tally

A tiny shared-expenses ledger library. Node 24, ES modules, no dependencies.

- Spec: `docs/spec.md` is binding and owner-only: nobody but the owner edits it. Roadmap and parked items: `docs/roadmap.md`.
- Money is integer centavos everywhere. Never use floats for money. Display goes through `formatPeso` in `src/money.js`.
- Business rules live in `src/ledger.js` and check permissions with `hasLevel` from `src/permissions.js`. Permission errors throw `Error('forbidden')`.
- Tests: `npm test` (node:test, files in `test/`). Lint: `npm run lint`.
- Preflight: npm run lint && npm test
EOF
  cat > docs/spec.md <<'EOF'
# tally spec (binding, owner-only)

## Model
A ledger has members `{ id, level }` with level `view` < `edit` < `owner`, and expenses `{ id, amount, paidBy, shares }`. Amounts are integer centavos.

## Adding expenses
`addExpense(ledger, { id, amount, paidBy }, actor)` needs `edit`. `amount` must be a positive integer, else throw `Error('invalid_amount')`.

## Splitting
`splitExpense(ledger, expenseId, memberIds, actor)` needs `edit`. It divides the expense amount equally among `memberIds` in centavos. Leftover centavos go one each to the first members in the order given, so shares always sum to the amount exactly. It stores and returns `shares` as an object `{ [memberId]: centavos }`. Unknown expense: throw `Error('not_found')`. Empty `memberIds` or an id that isn't a ledger member: throw `Error('invalid_members')`.
`shareOf(ledger, expenseId, memberId, actor)` needs `view` and returns that member's share in centavos, or 0.

## Refunds
`refund(ledger, expenseId, actor)` needs `owner`. It removes the expense and returns it. Unknown expense: throw `Error('not_found')`.

## Categories and totals
Expenses may carry `category` (a non-empty string; default `"general"`). `addExpense` accepts it. `totalsByCategory(ledger, actor)` needs `view` and returns `{ [category]: centavos }` summed over all expenses.

## Formatting
`formatPeso(centavos)` returns `₱` followed by the amount with thousands separators and exactly two decimals: `formatPeso(123456)` is `₱1,234.56`, `formatPeso(5)` is `₱0.05`, negative amounts are `-₱1.00`.
EOF
  cat > docs/roadmap.md <<'EOF'
# Roadmap

## Now
- Splitting, refunds, categories, formatting (see spec).

## Parked (out of scope until the owner unparks them)
- Multi-currency (any currency other than PHP).
- Recurring expenses.
EOF
  cat > src/permissions.js <<'EOF'
const order = ['view', 'edit', 'owner'];

/** True when `actor` is a ledger member whose level is at least `level`. */
export function hasLevel(ledger, actor, level) {
  const member = ledger.members.find((m) => m.id === actor);
  return Boolean(member) && order.indexOf(member.level) >= order.indexOf(level);
}
EOF
  cat > src/ledger.js <<'EOF'
import { hasLevel } from './permissions.js';

/** Creates an empty ledger with the given members. */
export function createLedger(members) {
  return { members, expenses: [] };
}

/** Adds an expense; needs edit. */
export function addExpense(ledger, { id, amount, paidBy }, actor) {
  if (!hasLevel(ledger, actor, 'edit')) throw new Error('forbidden');
  if (!Number.isInteger(amount) || amount <= 0) throw new Error('invalid_amount');
  const expense = { id, amount, paidBy, shares: {} };
  ledger.expenses.push(expense);
  return expense;
}
EOF
  cat > src/money.js <<'EOF'
// Display helpers for integer-centavo amounts. formatPeso is specified in docs/spec.md.
EOF
  cat > src/messages.js <<'EOF'
/** User-facing messages. */
export const messages = {
  paymentReceived: 'Payment Recieved',
  expenseAdded: 'Expense added',
};
EOF
  cat > test/ledger.test.js <<'EOF'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createLedger, addExpense } from '../src/ledger.js';

const members = [{ id: 'mia', level: 'owner' }, { id: 'ben', level: 'edit' }, { id: 'cy', level: 'view' }];

test('editor adds an expense', () => {
  const l = createLedger(members);
  addExpense(l, { id: 'e1', amount: 1000, paidBy: 'ben' }, 'ben');
  assert.equal(l.expenses.length, 1);
});

test('viewer cannot add', () => {
  const l = createLedger(members);
  assert.throws(() => addExpense(l, { id: 'e1', amount: 1000, paidBy: 'cy' }, 'cy'), /forbidden/);
});

test('rejects float amounts', () => {
  const l = createLedger(members);
  assert.throws(() => addExpense(l, { id: 'e1', amount: 10.5, paidBy: 'ben' }, 'ben'), /invalid_amount/);
});
EOF
  cat > scripts/lint.mjs <<'EOF'
// Minimal lint: no console.log, no var, no parseFloat in src/.
import { readdirSync, readFileSync } from 'node:fs';
let failed = false;
for (const f of readdirSync('src')) {
  readFileSync(`src/${f}`, 'utf8').split('\n').forEach((line, i) => {
    for (const [re, msg] of [[/console\.log/, 'no console.log'], [/\bvar\s/, 'no var'], [/parseFloat/, 'no parseFloat: money is integer centavos']]) {
      if (re.test(line)) { console.error(`src/${f}:${i + 1} ${msg}`); failed = true; }
    }
  });
}
process.exit(failed ? 1 : 0);
EOF
  cat > .claude/team.md <<'EOF'
# Team rules

## Sources of truth
- `docs/spec.md` (binding, owner-only: propose wording in the run folder instead of editing it).
- `docs/roadmap.md`: parked items are out of scope.

## Architecture rules
- Natural task seams: `src/money.js` (formatting), `src/ledger.js` (rules), tests beside each in `test/`.

## Commands
- `npm test`, `npm run lint`.

## QA must check
- Every permission level (view, edit, owner) on each new function, including a non-member.
- Money sums exactly; no floats.

## Docs
- The tech writer keeps `README.md` current (create it if missing, listing the public functions). Never edit `docs/spec.md`.

## Worktrees
- Off unless tasks overlap.
EOF
  cat > .claude/team-gate.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
npm run lint --silent
npm test --silent
EOF
  chmod +x .claude/team-gate.sh
  printf 'node_modules\n' > .gitignore
}

commit() { git init -q -b main && git add -A && git -c user.name=fixture -c user.email=fixture@example.com commit -qm init; }

for s in "${scenarios[@]}"; do
  rm -rf "tally-$s" && mkdir "tally-$s" && (cd "tally-$s" && base)
done

# gate: an extra rule only the gate knows about.
if has gate; then
cat > tally-gate/scripts/jsdoc.mjs <<'EOF'
// Every exported function in src/ must have a /** ... */ comment directly above it.
import { readdirSync, readFileSync } from 'node:fs';
let failed = false;
for (const f of readdirSync('src')) {
  const lines = readFileSync(`src/${f}`, 'utf8').split('\n');
  lines.forEach((line, i) => {
    if (/^export (async )?function/.test(line) && !/\*\/\s*$/.test(lines[i - 1] ?? '')) {
      console.error(`src/${f}:${i + 1} exported function needs a JSDoc comment`); failed = true;
    }
  });
}
process.exit(failed ? 1 : 0);
EOF
printf 'node scripts/jsdoc.mjs\n' >> tally-gate/.claude/team-gate.sh
# A handoff-only rule: the first gate run started by the plugin's hook (AGENT_TEAM_GATE=1)
# always fails, like a flaky integration check, so the hook's refusal path is exercised no
# matter how carefully the team prepares. Manual runs never trip it.
cat > gate-handoff-rule.sh <<EOF
#!/usr/bin/env bash
[ -f "$out/.gate-tripped" ] && exit 0
touch "$out/.gate-tripped"
echo "Handoff check failed: integration check timed out. Rerun bash .claude/team-gate.sh, then finish again."; exit 1
EOF
rm -f .gate-tripped
fi
chmod +x gate-handoff-rule.sh
printf 'if [ "${AGENT_TEAM_GATE:-}" = 1 ]; then bash "%s"; fi\n' "$out/gate-handoff-rule.sh" >> tally-gate/.claude/team-gate.sh

# worktree: always-on worktree mode.
has worktree && sed -i.bak 's/^- Off unless tasks overlap.$/- On: every engineer works in its own worktree. No shared services, so it is always safe./' tally-worktree/.claude/team.md && rm tally-worktree/.claude/team.md.bak

for s in "${scenarios[@]}"; do (cd "tally-$s" && commit && npm test --silent >/dev/null 2>&1 && npm run lint --silent); done
echo "fixtures in $out"
