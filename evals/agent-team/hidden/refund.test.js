import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createLedger, addExpense, refund } from '../src/ledger.js';

const members = [{ id: 'mia', level: 'owner' }, { id: 'ben', level: 'edit' }, { id: 'cy', level: 'view' }];
const setup = () => { const l = createLedger(members); addExpense(l, { id: 'e1', amount: 500, paidBy: 'ben' }, 'ben'); return l; };

test('hidden: owner refunds and gets the expense back', () => {
  const l = setup();
  assert.equal(refund(l, 'e1', 'mia').id, 'e1');
  assert.equal(l.expenses.length, 0);
});
test('hidden: editor, viewer and non-member cannot refund', () => {
  for (const who of ['ben', 'cy', 'zed']) assert.throws(() => refund(setup(), 'e1', who), /forbidden/);
});
test('hidden: unknown expense', () => {
  assert.throws(() => refund(setup(), 'nope', 'mia'), /not_found/);
});
