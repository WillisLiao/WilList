// The learning loop: what you actually did, compared with what you planned.

import { addDays, diffDays } from './dates.js';

const TYPE_WORD = { exam: 'Exam prep', presentation: 'Presentation prep', deadline: 'Homework', reading: 'Reading', task: 'Tasks' };

export function logFocus(s, { itemId, type, title, minutes, planned, completed, today }) {
  if (!(minutes >= 1)) return;
  s.log = [...(s.log || []), { date: today, itemId, type, title, minutes: Math.round(minutes), planned: planned || null, completed: !!completed }].slice(-500);
}

// How long things of a type really take compared with the plan, from finished
// focus sessions. Needs three data points before it says anything.
export function calibration(log, type) {
  const rows = (log || []).filter((x) => x.type === type && x.completed && x.planned > 0).slice(-20);
  if (rows.length < 3) return null;
  const ratio = rows.reduce((a, x) => a + x.minutes, 0) / rows.reduce((a, x) => a + x.planned, 0);
  return { ratio: Math.round(ratio * 10) / 10, n: rows.length, label: TYPE_WORD[type] || type };
}

export function calibrations(log, current = {}) {
  return ['exam', 'presentation', 'deadline', 'reading']
    .map((t) => ({ type: t, ...calibration(log, t) }))
    .filter((c) => c.ratio && Math.abs(c.ratio - (current[c.type] || 1)) >= 0.2);
}

export function noteFirstDone(s, today, letter) {
  const fd = { ...(s.meta.firstDone || {}) };
  if (fd[today]) return;
  fd[today] = letter || '-';
  for (const d of Object.keys(fd)) if (diffDays(d, today) > 60) delete fd[d];
  s.meta.firstDone = fd;
}

// Days in a row where the first thing you finished was an A (Tracy: a habit takes about 21 days).
export function a1Streak(firstDone, today) {
  const fd = firstDone || {};
  let d = fd[today] ? today : addDays(today, -1);
  let n = 0;
  while (fd[d] === 'A') { n++; d = addDays(d, -1); }
  return n;
}

export function weekStats(s, today) {
  const from = addDays(today, -6);
  const inWeek = (d) => d && diffDays(from, d) >= 0 && diffDays(d, today) >= 0;
  const focusMin = (s.log || []).filter((x) => inWeek(x.date)).reduce((a, x) => a + x.minutes, 0);
  let aDone = 0;
  let done = 0;
  for (const it of s.items) {
    const hits = [];
    if (it.done && inWeek(it.doneAt)) hits.push(1);
    for (const x of it.sessions || []) if (x.done && inWeek(x.doneAt) && !(it.done && x.doneAt === it.doneAt)) hits.push(1);
    for (const d of it.doneDates || []) if (inWeek(d)) hits.push(1);
    done += hits.length;
    if (it.priority === 'A') aDone += hits.length;
  }
  const days = Object.entries(s.meta.firstDone || {}).filter(([d]) => inWeek(d));
  return { focusMin, done, aDone, aFirstDays: days.filter(([, l]) => l === 'A').length, activeDays: days.length };
}
