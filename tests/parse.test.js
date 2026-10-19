import { test } from 'node:test';
import assert from 'node:assert/strict';
import { quickAdd, detectType } from '../app/src/parse.js';

// Monday 19 Oct 2026, 10:00
const now = new Date(2026, 9, 19, 10, 0);
const p = (s, opts = {}) => quickAdd(s, { now, ...opts });

test('exam with weekday, time and course tag', () => {
  const r = p('Calc midterm fri 2pm #MATH201');
  assert.equal(r.title, 'Calc midterm');
  assert.equal(r.type, 'exam');
  assert.equal(r.date, '2026-10-23');
  assert.equal(r.time, '14:00');
  assert.equal(r.course, 'MATH201');
});

test('homework with numeric date and "due"', () => {
  const r = p('HW3 due 10/24 11:59pm');
  assert.equal(r.title, 'HW3');
  assert.equal(r.type, 'deadline');
  assert.equal(r.date, '2026-10-24');
  assert.equal(r.time, '23:59');
});

test('day-first locales read 24/10 correctly', () => {
  assert.equal(p('Essay 24/10', { dateOrder: 'dmy' }).date, '2026-10-24');
});

test('weekly recurring meeting', () => {
  const r = p('Team meeting every tue 4pm');
  assert.equal(r.type, 'event');
  assert.deepEqual(r.recur, { freq: 'weekly', days: [2] });
  assert.equal(r.date, '2026-10-20');
  assert.equal(r.time, '16:00');
});

test('class timetable shorthand with a time range', () => {
  const r = p('Calculus lecture mwf 10-10:50am');
  assert.equal(r.title, 'Calculus lecture');
  assert.deepEqual(r.recur, { freq: 'weekly', days: [1, 3, 5] });
  assert.equal(r.time, '10:00');
  assert.equal(r.durationMin, 50);
  assert.equal(r.date, '2026-10-19');
});

test('afternoon range without am on the start', () => {
  const r = p('Bio lab every wed 2-5pm');
  assert.equal(r.time, '14:00');
  assert.equal(r.durationMin, 180);
  assert.equal(r.type, 'event');
});

test('"11-1pm" starts in the morning', () => {
  const r = p('Workshop 11-1pm tomorrow');
  assert.equal(r.time, '11:00');
  assert.equal(r.durationMin, 120);
});

test('every other week and multiple days', () => {
  assert.deepEqual(p('Advisor sync every other thu 3pm').recur, { freq: 'biweekly', days: [4] });
  assert.deepEqual(p('Gym every mon and wed 7am').recur, { freq: 'weekly', days: [1, 3] });
  assert.deepEqual(p('Tutoring tuesdays 5pm').recur, { freq: 'weekly', days: [2] });
});

test('"next mon" is Monday of next week', () => {
  assert.equal(p('Read Smith 2019 paper by next mon').date, '2026-10-26');
  assert.equal(p('Read Smith 2019 paper by next mon').type, 'reading');
  // On a Thursday, "next fri" is not tomorrow.
  const thu = new Date(2026, 9, 22, 9);
  assert.equal(quickAdd('Quiz next fri', { now: thu }).date, '2026-10-30');
});

test('relative days and month names', () => {
  assert.equal(p('Essay draft due in 2 weeks').date, '2026-11-02');
  assert.equal(p('Lab report due dec 5').date, '2026-12-05');
  assert.equal(p('Lab report due 5th dec').date, '2026-12-05');
  assert.equal(p('Apply for internship by jan 15').date, '2027-01-15');
  assert.equal(p('Pay fees tomorrow').date, '2026-10-20');
});

test('a past year-less date rolls to next year', () => {
  assert.equal(p('Register 1/10').date, '2027-01-10');
});

test('priority token and rank', () => {
  const r = p('Email TA about regrade !a2');
  assert.equal(r.priority, 'A');
  assert.equal(r.rank, 2);
  assert.equal(r.title, 'Email TA about regrade');
});

test('"at 3" means the afternoon', () => {
  assert.equal(p('Office hours thu at 3').time, '15:00');
});

test('time without a date lands today or tomorrow', () => {
  assert.equal(p('Call mom 6pm').date, '2026-10-19');
  assert.equal(p('Call mom 8am').date, '2026-10-20');
});

test('duration becomes effort', () => {
  const r = p('Study 2h for chem quiz on oct 22');
  assert.equal(r.durationMin, 120);
  assert.equal(r.title, 'Study for chem quiz');
  assert.equal(r.type, 'exam');
});

test('words it does not understand stay in the title', () => {
  const r = p('Problem set 5');
  assert.equal(r.title, 'Problem set 5');
  assert.equal(r.type, 'deadline');
  assert.equal(p('constructor toString').title, 'constructor toString');
});

test('victim-language hints', () => {
  assert.deepEqual(p('I will try to finish chapter 3 tonight').hints, ['try']);
  assert.ok(p('I have to do laundry').hints.includes('haveTo'));
  assert.ok(p('Fix wifi problem').hints.includes('problem'));
  assert.deepEqual(p('Problem set 5').hints, []);
});

test('type detection', () => {
  assert.equal(detectType('Final project report'), 'deadline');
  assert.equal(detectType('Final exam'), 'exam');
  assert.equal(detectType('Group presentation slides'), 'presentation');
  assert.equal(detectType('Office hours'), 'event');
  assert.equal(detectType('Lab report'), 'deadline');
  assert.equal(detectType('Buy groceries'), 'task');
  assert.equal(detectType('Review chapter 5'), 'reading');
});
