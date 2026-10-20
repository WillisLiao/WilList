import { test } from 'node:test';
import assert from 'node:assert/strict';
import { planDay } from '../app/src/timeline.js';

const ev = (time, durationMin, title = 'Class') => ({ id: title, title, type: 'event', time, durationMin });
const row = (label, priority, minutes, title = label) => ({
  key: label, label, priority, item: { id: title, title, sessions: [] },
  session: minutes ? { id: `${label}s`, minutes } : null, extra: 0,
});
const hhmm = (m) => `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`;
const work = (r) => r.slots.filter((s) => s.kind === 'work').map((s) => `${s.row.label}@${hhmm(s.start)}-${hhmm(s.end)}${s.part ? `#${s.part}` : ''}`);

test('work fills the gaps between classes, A’s first, with breaks', () => {
  const r = planDay({
    events: [ev('10:00', 50), ev('14:00', 180, 'Lab')],
    rows: [row('A1', 'A', 60), row('A2', 'A', 0), row('B1', 'B', 45)],
    nowMin: 9 * 60,
  });
  assert.deepEqual(work(r), ['A2@09:00-09:25', 'A1@10:55-11:55', 'B1@12:05-12:50']);
  assert.equal(r.unplaced.length, 0);
  assert.equal(r.slots.filter((s) => s.kind === 'event').length, 2);
});

test('a block too big for any gap is split across gaps', () => {
  const r = planDay({ events: [ev('09:00', 60), ev('11:00', 60)], rows: [row('A1', 'A', 150)], dayStart: '07:55', dayEnd: '13:00' });
  assert.deepEqual(work(r), ['A1@07:55-08:55#1', 'A1@10:05-10:55#2', 'A1@12:05-12:45#3']);
});

test('what does not fit today is reported, and D/E rows are never scheduled', () => {
  const r = planDay({ events: [], rows: [row('A1', 'A', 300), row('D1', 'D', 30), row('E1', 'E', 30)], dayStart: '20:00', dayEnd: '22:00' });
  assert.equal(r.unplaced.length, 1);
  assert.equal(r.unplaced[0].row.label, 'A1');
  assert.ok(!work(r).some((w) => w.startsWith('D') || w.startsWith('E')));
});

test('nothing is planned in the past', () => {
  const r = planDay({ events: [], rows: [row('A1', 'A', 30)], nowMin: 15 * 60 + 2 });
  assert.equal(work(r)[0], 'A1@15:05-15:35');
});
