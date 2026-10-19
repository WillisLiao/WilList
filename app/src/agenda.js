// Turns stored items into what the screens show: today's lettered list,
// the schedule, the 14-day radar and "the vital few".

import { addDays, diffDays, fromISO, weekday, weekStart } from './dates.js';

export const LETTERS = ['A', 'B', 'C', 'D', 'E'];
const RANK = { A: 0, B: 1, C: 2, D: 3, E: 4 };
const FIXED = new Set(['exam', 'presentation', 'event']);

export function occursOn(item, iso) {
  if (!item.date) return false;
  if (!item.recur) return item.date === iso;
  if (diffDays(item.date, iso) < 0) return false;
  if (item.recur.until && diffDays(iso, item.recur.until) < 0) return false;
  if (item.skips?.includes(iso)) return false;
  const wd = weekday(iso);
  switch (item.recur.freq) {
    case 'daily': return true;
    case 'weekdays': return wd >= 1 && wd <= 5;
    case 'weekly': return item.recur.days.includes(wd);
    case 'biweekly':
      return item.recur.days.includes(wd) &&
        Math.floor(diffDays(weekStart(item.date), weekStart(iso)) / 7) % 2 === 0;
    case 'monthly': return fromISO(iso).getDate() === fromISO(item.date).getDate();
    default: return false;
  }
}

// Exams, presentations and one-off events are finished once their day has passed.
export function isPast(item, today) {
  return FIXED.has(item.type) && !item.recur && !!item.date && diffDays(today, item.date) < 0;
}

export function isOpen(item, today) {
  return !item.done && !isPast(item, today);
}

export function byLetter(a, b) {
  const pa = a.priority ? RANK[a.priority] : -1;
  const pb = b.priority ? RANK[b.priority] : -1;
  if (pa !== pb) return pa - pb;
  if ((a.order ?? 0) !== (b.order ?? 0)) return (a.order ?? 0) - (b.order ?? 0);
  return (a.date || '9999').localeCompare(b.date || '9999');
}

// Fixed-time commitments for a day: classes, meetings, exams, presentations.
export function scheduleOn(items, iso) {
  return items
    .filter((it) => (it.type === 'event' && occursOn(it, iso)) ||
      ((it.type === 'exam' || it.type === 'presentation') && it.date === iso))
    .sort((a, b) => (a.time || '').localeCompare(b.time || ''));
}

function row(item, realToday, session = null, extra = 0) {
  const date = session ? session.date : item.date;
  return {
    key: session ? `${item.id}:${session.id}` : item.id,
    item,
    session,
    extra,
    priority: item.priority,
    order: item.order ?? 0,
    date: item.date,
    overdue: !!date && diffDays(realToday, date) < 0,
  };
}

// The actionable list for a day: one row per item, so a task never shows up twice.
// Unlettered items are left out: they wait in the "sort" tray. realToday lets the
// evening plan look at tomorrow without calling today's sessions "missed".
export function dayRows(items, day, realToday = day) {
  const rows = [];
  const sessionRow = (it, open) => {
    const due = open.filter((s) => diffDays(day, s.date) <= 0);
    if (due.length) rows.push(row(it, realToday, due[0], due.length - 1));
  };
  for (const it of items) {
    if (it.type === 'event' || !it.priority) continue;
    if (it.recur) {
      if (occursOn(it, day) && !(it.doneDates || []).includes(day)) rows.push({ ...row(it, realToday), overdue: false, recurring: true });
      continue;
    }
    if (!isOpen(it, realToday)) continue;
    const open = (it.sessions || []).filter((s) => !s.done);
    if (it.type === 'exam' || it.type === 'presentation') {
      if (diffDays(day, it.date) > 0) sessionRow(it, open);
      continue;
    }
    if (it.date && diffDays(day, it.date) <= 0) rows.push(row(it, realToday));
    else if (open.length) sessionRow(it, open);
    else if (!(it.plan && diffDays(day, it.plan) > 0)) rows.push(row(it, realToday));
  }
  rows.sort(byLetter);
  // A1, A2, B1 ... numbered in the order shown.
  const counters = {};
  for (const r of rows) {
    counters[r.priority] = (counters[r.priority] || 0) + 1;
    r.label = `${r.priority}${counters[r.priority]}`;
  }
  return rows;
}

export function unsorted(items, today) {
  return items
    .filter((it) => it.type !== 'event' && !it.priority && isOpen(it, today))
    .sort((a, b) => (a.date || '9999').localeCompare(b.date || '9999'));
}

export function doneOn(items, iso) {
  const out = [];
  for (const it of items) {
    if (it.recur && (it.doneDates || []).includes(iso)) out.push({ item: it });
    else if (it.done && it.doneAt === iso) out.push({ item: it });
    for (const s of it.sessions || []) if (s.done && s.doneAt === iso && !it.done) out.push({ item: it, session: s });
  }
  return out;
}

export function radar(items, today, days, perDayMin) {
  const out = [];
  for (let k = 0; k < days; k++) {
    const d = addDays(today, k);
    const schedule = scheduleOn(items, d);
    const due = items.filter((it) => !FIXED.has(it.type) && !it.recur && !it.done && it.date === d);
    const study = [];
    const starts = [];
    let load = 0;
    for (const it of items) {
      if (!isOpen(it, today) || !it.sessions?.length) continue;
      const todays = it.sessions.filter((s) => !s.done && s.date === d);
      if (todays.length) {
        const minutes = todays.reduce((a, s) => a + s.minutes, 0);
        load += minutes;
        study.push({ item: it, count: todays.length, minutes });
      }
      const firstOpen = it.sessions.find((s) => !s.done);
      const started = it.sessions.some((s) => s.done);
      if (!started && firstOpen && firstOpen.date === d) starts.push(it);
    }
    out.push({ date: d, schedule, due, study, starts, load, over: load > perDayMin });
  }
  return out;
}

export function missedSessions(items, today) {
  const out = [];
  for (const it of items) {
    if (!isOpen(it, today)) continue;
    const n = (it.sessions || []).filter((s) => !s.done && diffDays(today, s.date) < 0).length;
    if (n) out.push({ item: it, count: n });
  }
  return out;
}

// The few big things that decide the semester, with how far along each one is.
export function vitalFew(items, today, horizon = 45) {
  return items
    .filter((it) => ['exam', 'presentation', 'deadline', 'reading'].includes(it.type) &&
      (it.priority === 'A' || it.priority === 'B') && isOpen(it, today) && it.date &&
      diffDays(today, it.date) >= 0 && diffDays(today, it.date) <= horizon)
    .sort((a, b) => a.date.localeCompare(b.date) || byLetter(a, b))
    .map((it) => {
      const s = it.sessions || [];
      const done = s.filter((x) => x.done).length;
      const behind = s.some((x) => !x.done && diffDays(today, x.date) < 0);
      const firstOpen = s.find((x) => !x.done);
      let status = 'on-track';
      if (it.shortfallMin > 0) status = 'short';
      else if (behind) status = 'behind';
      else if (!done && firstOpen && diffDays(today, firstOpen.date) > 0) status = 'not-started';
      else if (!s.length) status = 'no-plan';
      return { item: it, done, total: s.length, status, startBy: firstOpen?.date || it.startBy };
    });
}

// "Urgent things are seldom important; important things are seldom urgent."
export function importantNotUrgent(items, today) {
  return items.filter((it) => it.priority === 'A' && isOpen(it, today) && it.date &&
    !it.recur && it.type !== 'event' && diffDays(today, it.date) > 3 && diffDays(today, it.date) <= 30)
    .sort((a, b) => a.date.localeCompare(b.date));
}
