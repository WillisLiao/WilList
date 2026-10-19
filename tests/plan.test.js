import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildPlan, suggestEffort } from '../app/src/plan.js';
import { diffDays } from '../app/src/dates.js';

const settings = { sessionMin: 50, perDayMin: 120, bufferDays: 1 };
const today = '2026-10-19';

test('exam sessions end the day before and never on exam day', () => {
  const r = buildPlan({ type: 'exam', date: '2026-10-31', effortMin: 480 }, settings, today);
  const dates = r.sessions.map((s) => s.date);
  assert.ok(dates.every((d) => d < '2026-10-31'));
  assert.equal(dates.at(-1), '2026-10-30');
  assert.equal(r.startBy, dates[0]);
  assert.ok(diffDays(today, r.startBy) >= 0);
  assert.equal(r.shortfallMin, 0);
  const total = r.sessions.reduce((a, s) => a + s.minutes, 0);
  assert.ok(total >= 480 && total < 480 + 50);
});

test('exam sessions are spaced when there is room', () => {
  // 3 sessions over a month: expanding gaps back from the day before.
  const r = buildPlan({ type: 'exam', date: '2026-11-20', effortMin: 150 }, settings, today);
  assert.deepEqual(r.sessions.map((s) => s.date), ['2026-11-16', '2026-11-18', '2026-11-19']);
  assert.match(r.sessions.at(-1).label, /Light review/);
});

test('small effort is not inflated into extra sessions', () => {
  const r = buildPlan({ type: 'reading', date: '2026-10-25', effortMin: 120 }, settings, today);
  assert.equal(r.sessions.length, 2);
  assert.equal(r.sessions[0].minutes, 60);
});

test('deadlines finish a buffer day early', () => {
  const r = buildPlan({ type: 'deadline', date: '2026-10-25', effortMin: 180 }, settings, today);
  assert.ok(r.sessions.every((s) => s.date <= '2026-10-24'));
  assert.match(r.sessions.at(-1).label, /submit/i);
});

test('not enough time reports a shortfall instead of overbooking', () => {
  const r = buildPlan({ type: 'exam', date: '2026-10-20', effortMin: 900 }, settings, today);
  assert.equal(r.sessions.length, 2);
  assert.ok(r.sessions.every((s) => s.date === today));
  assert.ok(r.shortfallMin > 0);
  const perDay = r.sessions.reduce((a, s) => a + s.minutes, 0);
  assert.ok(perDay <= settings.perDayMin);
});

test('exam today has no sessions left', () => {
  const r = buildPlan({ type: 'exam', date: today, effortMin: 300 }, settings, today);
  assert.equal(r.sessions.length, 0);
  assert.equal(r.shortfallMin, 300);
});

test('replanning keeps finished sessions and only plans what is left', () => {
  const done = { id: 'x', date: '2026-10-15', minutes: 60, label: 'old', done: true };
  const r = buildPlan({ type: 'exam', date: '2026-10-30', effortMin: 240, sessions: [done] }, settings, today);
  assert.equal(r.sessions[0], done);
  const fresh = r.sessions.filter((s) => !s.done);
  assert.equal(fresh.reduce((a, s) => a + s.minutes, 0), 180);
  assert.ok(fresh.every((s) => s.date >= today));
});

test('effort suggestions follow the kind of item', () => {
  assert.equal(suggestEffort('exam', 'Chem quiz'), 120);
  assert.equal(suggestEffort('exam', 'Calc final'), 900);
  assert.equal(suggestEffort('deadline', 'History essay'), 600);
  assert.equal(suggestEffort('task', 'Laundry'), 0);
});

test('plans around study time other items already booked', () => {
  // Today and tomorrow are already full; a 2-session job should land elsewhere.
  const load = new Map([['2026-10-19', 120], ['2026-10-20', 120]]);
  const r = buildPlan({ type: 'deadline', date: '2026-10-26', effortMin: 100 }, settings, today, load);
  assert.equal(r.sessions.length, 2);
  assert.ok(r.sessions.every((s) => s.date > '2026-10-20'), JSON.stringify(r.sessions.map((s) => s.date)));
});

test('overbooks only when there is no free day left before the deadline', () => {
  const load = new Map([['2026-10-19', 120]]);
  const r = buildPlan({ type: 'deadline', date: '2026-10-19', effortMin: 50 }, settings, today, load);
  assert.equal(r.sessions.length, 1);
  assert.equal(r.sessions[0].date, today);
  assert.equal(r.shortfallMin, 0);
});
