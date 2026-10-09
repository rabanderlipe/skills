// Hidden acceptance tests for the "full" scenario, copied in by check.py after the run.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createLedger, addExpense, splitExpense, shareOf } from '../src/ledger.js';
import { formatPeso } from '../src/money.js';

const members = [{ id: 'mia', level: 'owner' }, { id: 'ben', level: 'edit' }, { id: 'cy', level: 'view' }];
const setup = () => { const l = createLedger(members); addExpense(l, { id: 'e1', amount: 10000, paidBy: 'ben' }, 'ben'); return l; };

test('hidden: leftover centavos go to the first members in order', () => {
  assert.deepEqual(splitExpense(setup(), 'e1', ['cy', 'mia', 'ben'], 'ben'), { cy: 3334, mia: 3333, ben: 3333 });
});
test('hidden: shares sum exactly', () => {
  const l = createLedger(members); addExpense(l, { id: 'e2', amount: 101, paidBy: 'mia' }, 'mia');
  const s = splitExpense(l, 'e2', ['mia', 'ben', 'cy'], 'mia');
  assert.equal(Object.values(s).reduce((a, b) => a + b, 0), 101);
  assert.ok(Object.values(s).every(Number.isInteger));
});
test('hidden: viewer and non-member cannot split', () => {
  assert.throws(() => splitExpense(setup(), 'e1', ['mia'], 'cy'), /forbidden/);
  assert.throws(() => splitExpense(setup(), 'e1', ['mia'], 'zed'), /forbidden/);
});
test('hidden: split errors', () => {
  assert.throws(() => splitExpense(setup(), 'nope', ['mia'], 'ben'), /not_found/);
  assert.throws(() => splitExpense(setup(), 'e1', [], 'ben'), /invalid_members/);
  assert.throws(() => splitExpense(setup(), 'e1', ['zed'], 'ben'), /invalid_members/);
});
test('hidden: shareOf needs view, returns 0 for no share', () => {
  const l = setup(); splitExpense(l, 'e1', ['mia', 'ben'], 'ben');
  assert.equal(shareOf(l, 'e1', 'mia', 'cy'), 5000);
  assert.equal(shareOf(l, 'e1', 'cy', 'cy'), 0);
  assert.throws(() => shareOf(l, 'e1', 'mia', 'zed'), /forbidden/);
});
test('hidden: formatPeso', () => {
  assert.equal(formatPeso(123456), '₱1,234.56');
  assert.equal(formatPeso(5), '₱0.05');
  assert.equal(formatPeso(-100), '-₱1.00');
  assert.equal(formatPeso(0), '₱0.00');
  assert.equal(formatPeso(100000000), '₱1,000,000.00');
});
