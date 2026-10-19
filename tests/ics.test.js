import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildICS } from '../app/src/ics.js';
import { makeItem } from '../app/src/store.js';

const settings = { sessionMin: 50, perDayMin: 120, bufferDays: 1 };
const today = '2026-10-19';
const now = new Date(Date.UTC(2026, 9, 19, 12));

test('exports classes with RRULE, exams with alarms and study sessions', () => {
  const cls = makeItem({ title: 'Calculus lecture, room 2', type: 'event', date: today, time: '10:00', durationMin: 50, recur: { freq: 'weekly', days: [1, 3, 5] } }, settings, today);
  const exam = makeItem({ title: 'Calc midterm', type: 'exam', date: '2026-10-30', time: '09:00', priority: 'A', effortMin: 240 }, settings, today);
  const ics = buildICS([cls, exam], { today, now });
  assert.match(ics, /^BEGIN:VCALENDAR\r\n/);
  assert.match(ics, /END:VCALENDAR\r\n$/);
  assert.match(ics, /RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR/);
  assert.match(ics, /DTSTART:20261019T100000/);
  assert.match(ics, /DTEND:20261019T105000/);
  assert.match(ics, /SUMMARY:Calculus lecture\\, room 2/);
  assert.match(ics, /SUMMARY:\[A\] Exam: Calc midterm/);
  assert.match(ics, /TRIGGER:-P1D/);
  assert.match(ics, /SUMMARY:START Calc midterm/);
  const sessions = ics.match(/SUMMARY:.*Calc midterm: /g) || [];
  assert.equal(sessions.length, exam.sessions.length);
  const noSessions = buildICS([exam], { today, now, includeSessions: false });
  assert.ok(!/SUMMARY:.*Calc midterm: /.test(noSessions));
});

test('long lines are folded to 75 octets', () => {
  const t = makeItem({ title: 'Ü'.repeat(80), type: 'task', date: today }, settings, today);
  const ics = buildICS([t], { today, now });
  const enc = new TextEncoder();
  for (const line of ics.split('\r\n')) assert.ok(enc.encode(line).length <= 75, line);
});

test('done, eliminated and past items are left out', () => {
  const done = makeItem({ title: 'Done thing', type: 'task', date: today }, settings, today);
  done.done = true;
  const e = makeItem({ title: 'Dropped', type: 'task', date: today, priority: 'E' }, settings, today);
  const past = makeItem({ title: 'Old exam', type: 'exam', date: '2026-10-01' }, settings, today);
  const ics = buildICS([done, e, past], { today, now });
  assert.ok(!ics.includes('BEGIN:VEVENT'));
});
