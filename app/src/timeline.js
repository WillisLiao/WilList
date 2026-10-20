// Turns today's lettered list into a day: work goes into the free time between
// classes and meetings, A's first, with short breaks between blocks.

import { timeToMin } from './dates.js';

const WORK_LETTERS = new Set(['A', 'B', 'C']);

// Minutes a row still needs today.
export function rowMinutes(r, taskMin) {
  if (r.session) return r.session.minutes * (1 + (r.extra || 0));
  const open = (r.item.sessions || []).filter((s) => !s.done);
  if (open.length) return open.reduce((a, s) => a + s.minutes, 0);
  return taskMin;
}

export function planDay({ events, rows, dayStart = '08:00', dayEnd = '22:00', nowMin = null,
  breakMin = 10, taskMin = 25, minBlock = 20 }) {
  const start = Math.max(timeToMin(dayStart), nowMin == null ? 0 : Math.ceil(nowMin / 5) * 5);
  const end = timeToMin(dayEnd);
  const fixed = events.filter((e) => e.time)
    .map((e) => ({ kind: 'event', start: timeToMin(e.time), end: timeToMin(e.time) + (e.durationMin || 60), event: e }))
    .sort((a, b) => a.start - b.start);

  // Free segments between fixed commitments, with five minutes to get from one place to the next.
  const free = [];
  let cur = start;
  for (const f of fixed) {
    if (f.start - 5 > cur) free.push({ s: cur, e: Math.min(f.start - 5, end) });
    cur = Math.max(cur, f.end + 5);
  }
  if (cur < end) free.push({ s: cur, e: end });
  for (const g of free) if (g.e - g.s < minBlock) g.e = g.s;

  const slots = [];
  const unplaced = [];
  const take = (g, row, minutes, part) => {
    slots.push({ kind: 'work', start: g.s, end: g.s + minutes, row, part });
    g.s = Math.min(g.e, g.s + minutes + breakMin);
  };
  for (const row of rows.filter((r) => WORK_LETTERS.has(r.priority))) {
    let rem = rowMinutes(row, taskMin);
    const whole = free.find((g) => g.e - g.s >= rem);
    if (whole) { take(whole, row, rem, null); continue; }
    // Too big for any one gap: split it over the gaps that are long enough, in time order.
    if (rem >= 2 * minBlock) {
      let part = 1;
      for (const g of free) {
        if (rem <= 0) break;
        const space = g.e - g.s;
        if (space < minBlock) continue;
        const n = Math.min(space, rem);
        take(g, row, n, part++);
        rem -= n;
      }
    }
    if (rem > 0) unplaced.push({ row, minutes: rem });
  }
  const all = [...fixed, ...slots].sort((a, b) => a.start - b.start || (a.kind === 'event' ? -1 : 1));
  const freeMin = free.reduce((a, g) => a + Math.max(0, g.e - g.s), 0);
  return { slots: all, unplaced, freeMin, workMin: slots.reduce((a, x) => a + x.end - x.start, 0) };
}
