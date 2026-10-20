import { test } from 'node:test';
import assert from 'node:assert/strict';
import { occursOn, dayRows, unsorted, radar, vitalFew, scheduleOn, importantNotUrgent, isPast } from '../app/src/agenda.js';
import { makeItem, completeRow, setLetter, moveInList, replan, replanAll, emptyState, normalize } from '../app/src/store.js';
import { buildPlan } from '../app/src/plan.js';

const settings = { sessionMin: 50, perDayMin: 120, bufferDays: 1 };
const today = '2026-10-19'; // Monday

const mk = (fields) => makeItem(fields, settings, today);

test('weekly, biweekly, weekday and monthly recurrence', () => {
  const weekly = { date: '2026-10-19', recur: { freq: 'weekly', days: [1, 3] } };
  assert.ok(occursOn(weekly, '2026-10-21'));
  assert.ok(!occursOn(weekly, '2026-10-20'));
  assert.ok(!occursOn(weekly, '2026-10-12'), 'not before the start date');
  const bi = { date: '2026-10-20', recur: { freq: 'biweekly', days: [2] } };
  assert.ok(occursOn(bi, '2026-11-03'));
  assert.ok(!occursOn(bi, '2026-10-27'));
  const wd = { date: '2026-10-19', recur: { freq: 'weekdays' } };
  assert.ok(occursOn(wd, '2026-10-23') && !occursOn(wd, '2026-10-24'));
  const mo = { date: '2026-10-05', recur: { freq: 'monthly' } };
  assert.ok(occursOn(mo, '2026-11-05') && !occursOn(mo, '2026-11-06'));
  const skip = { date: '2026-10-19', recur: { freq: 'daily' }, skips: ['2026-10-20'] };
  assert.ok(!occursOn(skip, '2026-10-20'));
});

test('unlettered items wait in the sort tray, not the list', () => {
  const t = mk({ title: 'Buy groceries', type: 'task' });
  assert.equal(dayRows([t], today).length, 0);
  assert.equal(unsorted([t], today).length, 1);
});

test('list is ordered by letter, not by due date', () => {
  const urgentC = mk({ title: 'Return library book', type: 'task', date: today, priority: 'C' });
  const importantA = mk({ title: 'Essay', type: 'task', date: '2026-10-28', priority: 'A' });
  const rows = dayRows([urgentC, importantA], today);
  assert.deepEqual(rows.map((r) => r.label), ['A1', 'C1']);
  assert.equal(rows[0].item.title, 'Essay');
});

test('important-not-urgent exams surface through today’s session', () => {
  const exam = mk({ title: 'Calc midterm', type: 'exam', date: '2026-10-23', effortMin: 240, priority: 'A' });
  const rows = dayRows([exam], today);
  assert.ok(rows.length >= 1);
  assert.ok(rows.every((r) => r.session));
  assert.equal(importantNotUrgent([exam], today).length, 1);
});

test('future sessions stay off today until their day', () => {
  const exam = mk({ title: 'Final', type: 'exam', date: '2026-12-10', effortMin: 150, priority: 'A' });
  assert.equal(dayRows([exam], today).length, 0);
  const firstDay = exam.sessions[0].date;
  assert.ok(dayRows([exam], firstDay).length >= 1);
});

test('finishing the last session of a deadline completes it', () => {
  const s = emptyState();
  const hw = mk({ title: 'Problem set', type: 'deadline', date: '2026-10-21', effortMin: 50, priority: 'A' });
  s.items.push(hw);
  assert.equal(hw.sessions.length, 1);
  const r = completeRow(s, { itemId: hw.id, sessionId: hw.sessions[0].id }, hw.sessions[0].date);
  assert.ok(r.finishedItem);
  assert.ok(s.items[0].done);
});

test('due-today deadline shows once, with its open sessions folded in', () => {
  const hw = mk({ title: 'Lab report', type: 'deadline', date: today, effortMin: 100, priority: 'A' });
  const rows = dayRows([hw], today);
  assert.equal(rows.length, 1);
  assert.equal(rows[0].session, null);
});

test('recurring tasks complete per day', () => {
  const s = emptyState();
  const t = mk({ title: 'Review flashcards', type: 'task', date: today, recur: { freq: 'daily' }, priority: 'B' });
  s.items.push(t);
  assert.equal(dayRows(s.items, today).length, 1);
  completeRow(s, { itemId: t.id, recurring: true }, today);
  assert.equal(dayRows(s.items, today).length, 0);
  assert.equal(dayRows(s.items, '2026-10-20').length, 1);
});

test('re-ranking swaps A1 and A2', () => {
  const s = emptyState();
  s.items.push(mk({ title: 'First', type: 'task', priority: 'A', date: '2026-10-20' }));
  s.items.push(mk({ title: 'Second', type: 'task', priority: 'A', date: '2026-10-22' }));
  let rows = dayRows(s.items, today);
  assert.equal(rows[0].item.title, 'First');
  moveInList(s, rows, rows[1].key, -1);
  rows = dayRows(s.items, today);
  assert.equal(rows[0].item.title, 'Second');
  assert.equal(rows[0].label, 'A1');
});

test('setting a letter moves an item out of the tray', () => {
  const s = emptyState();
  s.items.push(mk({ title: 'Email professor', type: 'task' }));
  setLetter(s, s.items[0].id, 'A');
  assert.equal(unsorted(s.items, today).length, 0);
  assert.equal(dayRows(s.items, today)[0].label, 'A1');
});

test('schedule merges classes, exams and presentations by time', () => {
  const cls = mk({ title: 'Lecture', type: 'event', date: today, time: '10:00', recur: { freq: 'weekly', days: [1] } });
  const exam = mk({ title: 'Quiz', type: 'exam', date: today, time: '09:00' });
  assert.deepEqual(scheduleOn([cls, exam], today).map((x) => x.title), ['Quiz', 'Lecture']);
  assert.ok(isPast(exam, '2026-10-20'));
  assert.ok(!isPast(cls, '2026-10-20'));
});

test('radar flags overloaded days and start days', () => {
  const a = mk({ title: 'Exam A', type: 'exam', date: '2026-10-21', effortMin: 240, priority: 'A' });
  const b = mk({ title: 'Exam B', type: 'exam', date: '2026-10-21', effortMin: 240, priority: 'A' });
  const days = radar([a, b], today, 3, 120);
  assert.ok(days.some((d) => d.over));
  assert.ok(days[0].starts.length >= 1);
});

test('vital few reports progress and status', () => {
  const s = emptyState();
  const exam = mk({ title: 'Midterm', type: 'exam', date: '2026-10-30', effortMin: 240, priority: 'A' });
  s.items.push(exam);
  const [v] = vitalFew(s.items, today);
  assert.equal(v.total, exam.sessions.length);
  assert.equal(v.done, 0);
  // Missing a session marks it behind; replanning fixes that.
  const later = exam.sessions[0].date;
  const dayAfter = '2026-10-29';
  assert.equal(vitalFew(s.items, dayAfter)[0].status, later < dayAfter ? 'behind' : 'on-track');
  replan(s, exam.id, dayAfter);
  assert.notEqual(vitalFew(s.items, dayAfter)[0].status, 'behind');
});

test('an item shows once a day even with several sessions due', () => {
  const exam = mk({ title: 'Big final', type: 'exam', date: '2026-10-21', effortMin: 400, priority: 'A' });
  const rows = dayRows([exam], today);
  assert.equal(rows.length, 1);
  assert.ok(rows[0].extra >= 1);
});

test('looking at tomorrow, today’s sessions are carried over, not missed', () => {
  const hw = mk({ title: 'Essay', type: 'deadline', date: '2026-10-24', effortMin: 50, priority: 'A' });
  hw.sessions[0].date = today;
  const [r] = dayRows([hw], '2026-10-20', today);
  assert.equal(r.overdue, false);
  const [missed] = dayRows([hw], '2026-10-20');
  assert.equal(missed.overdue, true);
});

test('balancing gives A items first claim on each day', () => {
  const s = emptyState();
  // The B was added first and took the free study time; the A arrived later and got pushed aside.
  s.items.push(mk({ title: 'B reading', type: 'reading', date: '2026-10-21', effortMin: 200, priority: 'B' }));
  s.items.push(makeItem({ title: 'A exam', type: 'exam', date: '2026-10-27', effortMin: 240, priority: 'A' }, settings, today, s.items));
  const aloneDates = buildPlan({ type: 'exam', date: '2026-10-27', effortMin: 240 }, settings, today).sessions.map((x) => x.date);
  const a0 = s.items.find((x) => x.priority === 'A');
  assert.notDeepEqual(a0.sessions.map((x) => x.date), aloneDates, 'precondition: the B pushed the A off its best days');
  replanAll(s, today);
  const a = s.items.find((x) => x.priority === 'A');
  assert.deepEqual(a.sessions.map((x) => x.date), aloneDates);
  assert.equal(a.shortfallMin, 0);
});

test('delegated and eliminated items get no study sessions', () => {
  const s = emptyState();
  s.items.push(mk({ title: 'Group poster', type: 'deadline', date: '2026-10-28', effortMin: 180 }));
  assert.ok(s.items[0].sessions.length > 0);
  setLetter(s, s.items[0].id, 'D', today);
  assert.equal(s.items[0].sessions.length, 0);
  setLetter(s, s.items[0].id, 'A', today);
  assert.ok(s.items[0].sessions.length > 0);
});

test('quick to-dos survive a backup round trip; old backups and junk rows are handled', () => {
  assert.deepEqual(normalize({ items: [] }).todos, []);
  const kept = { id: 't1', title: 'Buy stamps', done: false, doneAt: null };
  assert.deepEqual(normalize({ todos: [kept, null, { id: 2 }, 'x'] }).todos, [kept]);
});
