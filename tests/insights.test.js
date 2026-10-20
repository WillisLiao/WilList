import { test } from 'node:test';
import assert from 'node:assert/strict';
import { logFocus, calibration, calibrations, a1Streak, weekStats } from '../app/src/insights.js';
import { emptyState, makeItem, completeRow } from '../app/src/store.js';

const today = '2026-10-20';
const settings = { sessionMin: 50, perDayMin: 120, bufferDays: 1 };

test('calibration needs three finished sessions, then reports the real/planned ratio', () => {
  const s = emptyState();
  const add = (minutes, planned) => logFocus(s, { itemId: 'x', type: 'deadline', title: 'PS', minutes, planned, completed: true, today });
  add(70, 50); add(65, 50);
  assert.equal(calibration(s.log, 'deadline'), null);
  add(75, 50);
  assert.deepEqual(calibration(s.log, 'deadline'), { ratio: 1.4, n: 3, label: 'Homework' });
  assert.equal(calibrations(s.log, {})[0].type, 'deadline');
  assert.equal(calibrations(s.log, { deadline: 1.4 }).length, 0, 'no suggestion once accepted');
  logFocus(s, { itemId: 'y', type: 'deadline', title: 'tiny', minutes: 0.4, planned: 50, completed: true, today });
  assert.equal(s.log.length, 3, 'sub-minute sessions are not logged');
});

test('accepted calibration scales new effort estimates', () => {
  const it = makeItem({ title: 'Problem set 7', type: 'deadline', date: '2026-10-30' }, { ...settings, calib: { deadline: 1.5 } }, today);
  assert.equal(it.effortMin, 270);
});

test('A1-first streak counts days whose first finished item was an A', () => {
  const fd = { '2026-10-17': 'A', '2026-10-18': 'B', '2026-10-19': 'A', '2026-10-20': 'A' };
  assert.equal(a1Streak(fd, today), 2);
  assert.equal(a1Streak({ '2026-10-19': 'A' }, today), 1, 'today not started yet still counts yesterday');
  assert.equal(a1Streak({ '2026-10-20': 'C', '2026-10-19': 'A' }, today), 0);
});

test('completing the first item of the day records its letter', () => {
  const s = emptyState();
  s.items.push(makeItem({ title: 'B thing', type: 'task', priority: 'B' }, settings, today));
  s.items.push(makeItem({ title: 'A thing', type: 'task', priority: 'A' }, settings, today));
  completeRow(s, { itemId: s.items[0].id }, today);
  completeRow(s, { itemId: s.items[1].id }, today);
  assert.equal(s.meta.firstDone[today], 'B');
  const w = weekStats(s, today);
  assert.equal(w.done, 2);
  assert.equal(w.aDone, 1);
  assert.equal(w.aFirstDays, 0);
});
