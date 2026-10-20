import { test } from 'node:test';
import assert from 'node:assert/strict';
import { importICS, parseSyllabus, planImport, mapRRule, courseCode, icsDateTime } from '../app/src/importer.js';
import { makeItem, applyImport, emptyState, suggestedLetter } from '../app/src/store.js';

const today = '2026-10-20'; // Tuesday
const now = new Date(2026, 9, 20, 9, 0);
const settings = { sessionMin: 50, perDayMin: 120, bufferDays: 1 };

const CANVAS = [
  'BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//Instructure//Canvas//EN',
  'BEGIN:VEVENT', 'UID:event-assignment-48211', 'DTSTART:20261024T035900Z', 'DTEND:20261024T035900Z',
  'SUMMARY:Problem Set 6 [MATH 201 Fall 2026]', 'DESCRIPTION:Sections 4.1–4.3\\, odd problems', 'END:VEVENT',
  'BEGIN:VEVENT', 'UID:event-assignment-48212', 'DTSTART;VALUE=DATE:20261030', 'DTEND;VALUE=DATE:20261031',
  'SUMMARY:Midterm Exam [MATH 201 Fall 2026]', 'END:VEVENT',
  'BEGIN:VEVENT', 'UID:event-assignment-40000', 'DTSTART:20261001T035900Z', 'DTEND:20261001T035900Z',
  'SUMMARY:Problem Set 1 [MATH 201 Fall 2026]', 'END:VEVENT',
  'BEGIN:VEVENT', 'UID:event-assignment-48213', 'DTSTART:20261106T170000Z', 'DTEND:20261106T170000Z',
  'SUMMARY:Essay draft: the printing press and the Reformation in Northern Eur',
  ' ope [HIST 150]', 'END:VEVENT',
  'END:VCALENDAR',
].join('\r\n');

test('Canvas feed: course codes, due times, past items skipped, folded lines joined', () => {
  const r = importICS(CANVAS, today);
  assert.equal(r.past, 1);
  assert.equal(r.items.length, 3);
  const ps = r.items[0];
  assert.equal(ps.title, 'Problem Set 6');
  assert.equal(ps.course, 'MATH201');
  assert.equal(ps.type, 'deadline');
  assert.equal(ps.externalId, 'ics:event-assignment-48211');
  assert.equal(ps.notes, 'Sections 4.1–4.3, odd problems');
  // 03:59Z is the evening before in America timezones; the local date/time is derived, not copied.
  const local = new Date(Date.UTC(2026, 9, 24, 3, 59));
  assert.equal(ps.time, `${String(local.getHours()).padStart(2, '0')}:${String(local.getMinutes()).padStart(2, '0')}`);
  const exam = r.items[1];
  assert.equal(exam.type, 'exam');
  assert.equal(exam.date, '2026-10-30');
  assert.equal(exam.time, null);
  assert.match(r.items[2].title, /Northern Europe$/);
  assert.equal(r.items[2].course, 'HIST150');
});

test('Moodle feed: "is due" trimmed, "opens" events ignored, course from CATEGORIES', () => {
  const ics = [
    'BEGIN:VCALENDAR',
    'BEGIN:VEVENT', 'UID:1234@moodle.uni.edu', 'SUMMARY:Lab report 3 is due', 'CATEGORIES:CHEM 110 - General Chemistry',
    'DTSTART:20261027T225900Z', 'DTEND:20261027T225900Z', 'END:VEVENT',
    'BEGIN:VEVENT', 'UID:1235@moodle.uni.edu', 'SUMMARY:Quiz 4 opens', 'DTSTART:20261026T120000Z', 'END:VEVENT',
    'END:VCALENDAR'].join('\n');
  const r = importICS(ics, today);
  assert.equal(r.items.length, 1);
  assert.equal(r.ignored, 1);
  assert.equal(r.items[0].title, 'Lab report 3');
  assert.equal(r.items[0].course, 'CHEM110');
  assert.equal(r.items[0].type, 'deadline');
});

test('Google class with a timezone, weekly rule and an exception date', () => {
  const ics = [
    'BEGIN:VCALENDAR', 'BEGIN:VEVENT', 'UID:abc@google.com', 'SUMMARY:Organic Chemistry Lecture',
    'DTSTART;TZID=America/New_York:20260901T100000', 'DTEND;TZID=America/New_York:20260901T105000',
    'RRULE:FREQ=WEEKLY;BYDAY=TU,TH;UNTIL=20261211T235959Z', 'EXDATE;TZID=America/New_York:20261126T100000',
    'END:VEVENT', 'END:VCALENDAR'].join('\r\n');
  const [ev] = importICS(ics, today).items;
  assert.equal(ev.type, 'event');
  assert.deepEqual(ev.recur, { freq: 'weekly', days: [2, 4], until: '2026-12-11' });
  assert.equal(ev.durationMin, 50);
  const d = icsDateTime({ value: '20260901T100000', params: { TZID: 'America/New_York' } });
  const expected = new Date(Date.UTC(2026, 8, 1, 14, 0)); // 10:00 EDT = 14:00 UTC
  assert.equal(d.time, `${String(expected.getHours()).padStart(2, '0')}:${String(expected.getMinutes()).padStart(2, '0')}`);
  assert.equal(ev.skips.length, 1);
});

test('repeat rules map onto WilList repeats', () => {
  assert.deepEqual(mapRRule('FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR', '2026-10-19'), { freq: 'weekdays' });
  assert.deepEqual(mapRRule('FREQ=WEEKLY;INTERVAL=2;BYDAY=FR', '2026-10-23'), { freq: 'biweekly', days: [5] });
  assert.equal(mapRRule('FREQ=YEARLY', '2026-10-23'), null);
  assert.equal(mapRRule('FREQ=WEEKLY;BYDAY=MO;COUNT=4', '2026-10-19').until, '2026-11-15');
});

test('course codes', () => {
  assert.equal(courseCode('MATH 201 Fall 2026'), 'MATH201');
  assert.equal(courseCode('CS 50'), 'CS50');
  assert.equal(courseCode('Intro to Psychology'), 'Intro to Psychology');
});

const SYLLABUS = `HIST 150 — Schedule (subject to change)
Week 1 (Sep 1): Introduction
Sep 22 – Reading response 1 due
Oct 27: Reading: Eisenstein ch. 2-3
Week 9 Thu: Map quiz (5%)
Oct 30	Lecture: Luther and print	Primary source analysis due (10%)
Nov 13: Midterm exam (25%)
Nov 24 - No class (Thanksgiving)
• Dec 8: Final presentation (20%); final paper due Dec 11 (30%)`;

test('syllabus: dated lines become items, past ones are dropped, deliverables pre-selected', () => {
  const { rows, past } = parseSyllabus(SYLLABUS, { now, course: 'HIST150', week1: '2026-08-31' });
  const byTitle = Object.fromEntries(rows.map((r) => [r.fields.title, r]));
  assert.equal(past, 2);
  assert.ok(byTitle['Midterm exam'].keep);
  assert.equal(byTitle['Midterm exam'].fields.weightPct, 25);
  assert.equal(byTitle['Midterm exam'].fields.type, 'exam');
  assert.equal(byTitle['Midterm exam'].fields.course, 'HIST150');
  assert.equal(byTitle['Map quiz'].fields.date, '2026-10-29'); // week 9 Thursday from a Monday Aug 31 start
  assert.equal(byTitle['Primary source analysis'].fields.date, '2026-10-30');
  assert.equal(byTitle['Primary source analysis'].fields.weightPct, 10);
  assert.ok(!byTitle['Lecture: Luther and print'].keep);
  assert.equal(byTitle['Reading: Eisenstein ch. 2-3'].fields.type, 'reading');
  assert.equal(byTitle['Final presentation'].fields.type, 'presentation');
  assert.equal(byTitle['Final paper'].fields.date, '2026-12-11');
  assert.equal(byTitle['Final paper'].fields.weightPct, 30);
  assert.ok(!byTitle['No class (Thanksgiving)']?.keep);
});

test('a syllabus pasted in December for spring keeps January dates in the future', () => {
  const dec = new Date(2026, 11, 10, 9);
  const { rows } = parseSyllabus('Jan 20: Quiz 1\nFeb 3 - Essay 1 due', { now: dec });
  assert.deepEqual(rows.map((r) => r.fields.date), ['2027-01-20', '2027-02-03']);
});

test('re-importing a calendar updates instead of duplicating', () => {
  const s = emptyState();
  const first = importICS(CANVAS, today);
  const plan1 = planImport(s.items, first.items);
  assert.equal(plan1.adds.length, 3);
  applyImport(s, plan1, today);
  s.items[0].priority = 'A';
  const moved = CANVAS.replace('DTSTART:20261024T035900Z', 'DTSTART:20261026T035900Z');
  const plan2 = planImport(s.items, importICS(moved, today).items);
  assert.equal(plan2.adds.length, 0);
  assert.equal(plan2.updates.length, 1);
  assert.equal(plan2.same, 2);
  applyImport(s, plan2, today);
  assert.equal(s.items.length, 3);
  assert.equal(s.items[0].priority, 'A', 'your letter survives a re-import');
  assert.notEqual(s.items[0].date, first.items[0].date);
});

test('pasted items already in the list are recognised by title and date', () => {
  const s = emptyState();
  s.items.push(makeItem({ title: 'Midterm exam', type: 'exam', date: '2026-11-13' }, settings, today));
  const { rows } = parseSyllabus('Nov 13: Midterm exam (25%)', { now });
  const plan = planImport(s.items, rows.map((r) => r.fields));
  assert.equal(plan.adds.length, 0);
  assert.equal(plan.same, 1);
});

test('grade weight drives the suggested letter', () => {
  assert.equal(suggestedLetter('deadline', 30), 'A');
  assert.equal(suggestedLetter('exam', 5), 'B');
  assert.equal(suggestedLetter('deadline', 1), 'C');
  assert.equal(suggestedLetter('exam', null), 'A');
  assert.equal(suggestedLetter('task', null), null);
});
