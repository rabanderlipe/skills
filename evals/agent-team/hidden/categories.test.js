import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createLedger, addExpense, totalsByCategory } from '../src/ledger.js';

const members = [{ id: 'mia', level: 'owner' }, { id: 'ben', level: 'edit' }, { id: 'cy', level: 'view' }];

test('hidden: totals by category with general default', () => {
  const l = createLedger(members);
  addExpense(l, { id: 'a', amount: 1000, paidBy: 'ben', category: 'food' }, 'ben');
  addExpense(l, { id: 'b', amount: 250, paidBy: 'ben', category: 'food' }, 'ben');
  addExpense(l, { id: 'c', amount: 99, paidBy: 'mia' }, 'mia');
  assert.deepEqual(totalsByCategory(l, 'cy'), { food: 1250, general: 99 });
});
test('hidden: non-member cannot read totals', () => {
  assert.throws(() => totalsByCategory(createLedger(members), 'zed'), /forbidden/);
});
