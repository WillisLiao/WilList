// Backward planning: turn "exam on the 30th, ~8h of prep" into dated sessions
// and a start date, so important-but-not-urgent work shows up before it is urgent.

import { addDays, diffDays } from './dates.js';

export const PLANNED_TYPES = ['exam', 'presentation', 'deadline', 'reading'];

export const EFFORT_PRESETS = {
  exam: [['Quiz', 120], ['Test', 360], ['Midterm', 480], ['Final', 900]],
  presentation: [['Short', 120], ['Standard', 240], ['Big', 480]],
  deadline: [['Small', 60], ['Homework', 180], ['Project', 600]],
  reading: [['Article', 60], ['Paper', 120], ['Chapters', 240]],
};

export function suggestEffort(type, title = '') {
  const t = title.toLowerCase();
  switch (type) {
    case 'exam':
      if (/\bquiz/.test(t)) return 120;
      if (/\bfinals?\b/.test(t)) return 900;
      if (/\bmidterms?\b/.test(t)) return 480;
      return 360;
    case 'presentation':
      return /\b(defen[cs]e|thesis|final)\b/.test(t) ? 480 : 240;
    case 'deadline':
      if (/\b(thesis|dissertation)\b/.test(t)) return 1200;
      if (/\b(project|report|essay|paper|portfolio)\b/.test(t)) return 600;
      if (/\b(application|apply)\b/.test(t)) return 240;
      return 180;
    case 'reading':
      if (/\bpapers?\b/.test(t)) return 120;
      if (/\b(chapters|book|textbook)\b/.test(t)) return 240;
      return 120;
    default:
      return 0;
  }
}

// Exams get expanding gaps (spaced repetition) counted back from the day before.
const EXAM_OFFSETS = [0, 1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 66, 78, 91];
// Everything else: every other day back from the last working day.
const STEADY_OFFSETS = Array.from({ length: 40 }, (_, i) => i * 2);

// Last day work should happen on, or null if it is too late for a plan.
function lastWorkDay(type, due, today, bufferDays) {
  const gap = diffDays(today, due);
  if (gap < 0) return null;
  if (type === 'exam' || type === 'presentation') return gap >= 1 ? addDays(due, -1) : null;
  // Deadlines: finish a buffer day early when there is room.
  const buffered = addDays(due, -Math.min(bufferDays, gap));
  return buffered;
}

// Picks days for n sessions. cap(d) limits sessions per day; counts/order carry
// over between passes so a second, looser pass can top up the first.
function pickDays({ window, n, maxPerDay, offsets, protectLast, cap, counts, order }) {
  const add = (d) => { counts.set(d, counts.get(d) + 1); order.push(d); };
  for (const off of offsets) {
    if (order.length >= n) break;
    const d = window[off];
    if (d && counts.get(d) === 0 && cap(d) > 0) add(d);
  }
  for (const d of window) {
    if (order.length >= n) break;
    if (counts.get(d) === 0 && cap(d) > 0) add(d);
  }
  // Doubles go nearest the deadline first, keeping the final day light.
  const doubleOrder = protectLast && window.length > 1 ? [...window.slice(1), window[0]] : window;
  for (let round = 1; order.length < n && round < maxPerDay; round++) {
    for (const d of doubleOrder) {
      if (order.length >= n) break;
      if (counts.get(d) === round && counts.get(d) < cap(d)) add(d);
    }
  }
}

// Minutes of open study already planned per day, by every other item.
export function studyLoad(items, excludeId) {
  const load = new Map();
  for (const it of items || []) {
    if (it.id === excludeId || it.done || it.priority === 'D' || it.priority === 'E') continue;
    for (const x of it.sessions || []) if (!x.done) load.set(x.date, (load.get(x.date) || 0) + x.minutes);
  }
  return load;
}

function labelFor(type, k, n) {
  const last = k === n - 1;
  const first = k === 0;
  switch (type) {
    case 'exam':
      if (n === 1) return 'Review + practice questions';
      if (first) return 'First pass: list every topic, mark the gaps';
      if (last) return 'Light review, then sleep early';
      return `Recall practice ${k + 1}/${n}: test yourself, no notes`;
    case 'presentation':
      if (n === 1) return 'Prepare + rehearse out loud';
      if (first) return 'Write your one key message + outline';
      if (last) return 'Final run-through out loud, timed';
      if (k === 1) return 'Build slides / script';
      return `Rehearse out loud ${k - 1}`;
    case 'reading':
      if (n === 1) return 'Read + write 3 takeaways';
      if (last) return 'Finish + write 3 takeaways';
      return `Read part ${k + 1}/${n}`;
    default:
      if (n === 1) return 'Do it + submit';
      if (first) return 'Start: break it into steps';
      if (last) return 'Finish + submit early';
      return `Work session ${k + 1}/${n}`;
  }
}

let seq = 0;
const sid = () => `s${Date.now().toString(36)}${(seq++).toString(36)}`;

// Builds sessions for the effort that is still left. Sessions already done are kept.
export function buildPlan(item, settings, today, load = new Map()) {
  const sessionMin = Math.max(15, settings.sessionMin || 50);
  const perDayMin = Math.max(sessionMin, settings.perDayMin || 120);
  const bufferDays = settings.bufferDays ?? 1;
  const kept = (item.sessions || []).filter((s) => s.done);
  const doneMin = kept.reduce((a, s) => a + s.minutes, 0);
  const remaining = Math.max(0, (item.effortMin || 0) - doneMin);
  const result = { sessions: kept, startBy: item.date || null, shortfallMin: 0 };
  if (!PLANNED_TYPES.includes(item.type) || !item.date || remaining <= 0) {
    result.startBy = kept.length ? kept[0].date : item.date;
    return result;
  }
  const last = lastWorkDay(item.type, item.date, today, bufferDays);
  if (!last || diffDays(today, last) < 0) {
    result.shortfallMin = remaining;
    result.startBy = today;
    return result;
  }
  const window = [];
  for (let d = last; diffDays(today, d) >= 0; d = addDays(d, -1)) window.push(d);
  // Split the effort into roughly session-sized blocks without inflating it.
  const n = Math.max(1, Math.round(remaining / sessionMin));
  const each = Math.ceil(remaining / n / 5) * 5;
  const maxPerDay = Math.max(1, Math.floor(perDayMin / each));
  const counts = new Map(window.map((d) => [d, 0]));
  const order = [];
  const base = { window, n, maxPerDay, counts, order, offsets: item.type === 'exam' ? EXAM_OFFSETS : STEADY_OFFSETS,
    protectLast: item.type === 'exam' || item.type === 'presentation' };
  // First fit around what other items already booked.
  const free = (d) => Math.min(maxPerDay, Math.floor((perDayMin - (load.get(d) || 0)) / each));
  pickDays({ ...base, cap: free });
  // If it does not fit, overbook where it hurts least: the day with the least study on it.
  while (order.length < n) {
    let best = null;
    let bestTotal = Infinity;
    for (const d of window) {
      if (counts.get(d) >= maxPerDay) continue;
      const total = (load.get(d) || 0) + counts.get(d) * each;
      if (total < bestTotal) { best = d; bestTotal = total; }
    }
    if (!best) break;
    counts.set(best, counts.get(best) + 1);
    order.push(best);
  }
  if (order.length < n) result.shortfallMin = Math.max(0, remaining - order.length * each);
  const days = order.sort();
  const fresh = days.map((date, k) => ({
    id: sid(),
    date,
    minutes: each,
    label: labelFor(item.type, k + kept.length, days.length + kept.length),
    done: false,
  }));
  result.sessions = [...kept, ...fresh].sort((a, b) => a.date.localeCompare(b.date));
  result.startBy = result.sessions[0]?.date || today;
  return result;
}

export function sessionProgress(item) {
  const s = item.sessions || [];
  return { done: s.filter((x) => x.done).length, total: s.length };
}
