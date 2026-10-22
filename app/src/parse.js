// Quick-add parser: turns "Calc midterm fri 2pm #math" into a structured item.
// It is deliberately forgiving: anything it does not understand stays in the title.

import { addDays, weekday, isValidISO, pad, diffDays } from './dates.js';

const dict = (o) => Object.assign(Object.create(null), o);
const WD = dict({
  sun: 0, sunday: 0, mon: 1, monday: 1, tue: 2, tues: 2, tuesday: 2,
  wed: 3, weds: 3, wednesday: 3, thu: 4, thur: 4, thurs: 4, thursday: 4,
  fri: 5, friday: 5, sat: 6, saturday: 6,
});
const MONTHS = dict({
  jan: 1, january: 1, feb: 2, february: 2, mar: 3, march: 3, apr: 4, april: 4,
  may: 5, jun: 6, june: 6, jul: 7, july: 7, aug: 8, august: 8, sep: 9, sept: 9,
  september: 9, oct: 10, october: 10, nov: 11, november: 11, dec: 12, december: 12,
});
// Student timetable shorthand. "tr" is only trusted after "every".
const SHORT_DAYS = dict({ mwf: [1, 3, 5], mw: [1, 3], wf: [3, 5], tth: [2, 4], tuth: [2, 4], mtwtf: [1, 2, 3, 4, 5] });
const COUNTERS = new Set(['week', 'wk', 'unit', 'chapter', 'chapters', 'ch', 'lecture', 'module', 'part', 'session', 'day', 'lab', 'quiz', 'set', 'hw', 'test', 'exam', 'assignment', 'problem', 'no', '#']);
const CONNECTORS = new Set(['due', 'by', 'on', 'at', '@', 'before', 'from', 'for', 'this', 'starting', 'every', 'each']);

export const TYPES = ['task', 'deadline', 'exam', 'presentation', 'reading', 'event'];

export function detectType(text) {
  const t = text.toLowerCase();
  const has = (re) => re.test(t);
  if (has(/\b(present|presentation|presenting|talk|pitch|defen[cs]e|demo|speech|slides|poster session)\b/)) return 'presentation';
  const deliverable = /\b(report|essay|project|paper|thesis|draft|assignment|portfolio)\b/;
  if (has(/\b(exams?|midterms?|quiz(zes)?|tests?|finals?|oral exam|mock exam)\b/) && !has(deliverable)) return 'exam';
  if (has(/\b(read|reading|skim|chapters?|ch\.?\s?\d+|textbook|article|literature)\b/)) return 'reading';
  if (has(/\b(hw\d*|homework|assignment|essay|project|report|psets?|problem sets?|worksheet|paper|thesis|draft|submit|submission|application|apply|due|portfolio|lab report)\b/)) return 'deadline';
  if (has(/\b(meeting|meet|class|lecture|seminar|tutorial|lab|office hours?|club|practice|rehearsal|call|sync|standup|appointment|interview|recitation|discussion section|study group|training|shift|game)\b/)) return 'event';
  return 'task';
}

function clean(tok) {
  return tok.toLowerCase().replace(/^[("'[]+|[)"'\].,;:!?]+$/g, '');
}

function upcomingWeekday(today, wd) {
  const delta = (wd - weekday(today) + 7) % 7;
  return addDays(today, delta);
}

function makeISO(y, m, d) {
  const iso = `${y}-${pad(m)}-${pad(d)}`;
  return isValidISO(iso) ? iso : null;
}

// A year-less date: in quick add, one that already passed means next year.
// In a pasted syllabus ("nearest"), pick whichever year is closest to today,
// so September dates pasted in October stay in the past and get skipped.
function resolveYearless(m, d, today, yearMode = 'future') {
  const y = Number(today.slice(0, 4));
  const iso = makeISO(y, m, d);
  if (!iso) return null;
  if (yearMode === 'nearest') {
    const cands = [makeISO(y - 1, m, d), iso, makeISO(y + 1, m, d)].filter(Boolean);
    return cands.sort((a, b) => Math.abs(diffDays(today, a)) - Math.abs(diffDays(today, b)))[0];
  }
  return diffDays(today, iso) < -7 ? makeISO(y + 1, m, d) : iso;
}

function to24(h, min, mer) {
  if (h > 23 || min > 59) return null;
  if (mer) {
    if (h < 1 || h > 12) return null;
    if (mer === 'pm' && h !== 12) h += 12;
    if (mer === 'am' && h === 12) h = 0;
  }
  return `${pad(h)}:${pad(min)}`;
}

// Bare hours without am/pm: 1-6 are almost always afternoon on a student's day.
function guessHour(h) {
  if (h >= 1 && h <= 6) return h + 12;
  return h;
}

function normMer(s) {
  if (!s) return null;
  return s[0] === 'p' ? 'pm' : 'am';
}

function parseClock(s) {
  // 2pm, 2:30pm, 11:59pm, 14:00, 9:30
  let m = s.match(/^(\d{1,2})(?::(\d{2}))?(am|pm|a|p)$/);
  if (m) return to24(Number(m[1]), Number(m[2] || 0), normMer(m[3]));
  m = s.match(/^(\d{1,2}):(\d{2})$/);
  if (m) {
    const h = Number(m[1]);
    return to24(h < 13 && m[1].length === 1 ? guessHour(h) : h, Number(m[2]), null);
  }
  if (s === 'noon') return '12:00';
  if (s === 'midnight') return '23:59';
  return null;
}

function parseRange(s) {
  // 2-5pm, 10-10:50am, 3pm-5pm, 15:00-17:00, 11-1pm
  const m = s.match(/^(\d{1,2})(?::(\d{2}))?(am|pm|a|p)?[-–](\d{1,2})(?::(\d{2}))?(am|pm|a|p)?$/);
  if (!m) return null;
  let [, h1, m1, a1, h2, m2, a2] = m;
  a1 = normMer(a1);
  a2 = normMer(a2);
  if (!a1 && !a2 && !m1 && !m2) return null; // "3-5" is probably not a time
  h1 = Number(h1); h2 = Number(h2); m1 = Number(m1 || 0); m2 = Number(m2 || 0);
  let start;
  let end;
  if (a2 && !a1) {
    end = to24(h2, m2, a2);
    // "11-1pm" starts in the morning; "2-5pm" starts in the afternoon.
    const tryStart = to24(h1, m1, a2);
    start = tryStart && end && tryStart <= end ? tryStart : to24(h1, m1, a2 === 'pm' ? 'am' : 'pm');
  } else if (a1 || a2) {
    start = to24(h1, m1, a1 || a2);
    end = to24(h2, m2, a2 || a1);
  } else {
    start = to24(h1 < 13 && h1 <= 6 ? h1 + 12 : h1, m1, null);
    end = to24(h2 < 13 && h2 <= 7 ? h2 + 12 : h2, m2, null);
  }
  if (!start || !end) return null;
  const toMin = (t) => Number(t.slice(0, 2)) * 60 + Number(t.slice(3));
  let dur = toMin(end) - toMin(start);
  if (dur <= 0) dur += 1440;
  return { time: start, durationMin: dur };
}

function parseDuration(s, next) {
  let m = s.match(/^~?(\d+(?:\.\d+)?)(h|hr|hrs|hour|hours|m|min|mins|minute|minutes)$/);
  if (m) return { min: Math.round(Number(m[1]) * (m[2][0] === 'h' ? 60 : 1)), used: 1 };
  m = s.match(/^~?(\d+(?:\.\d+)?)$/);
  if (m && next && /^(h|hr|hrs|hour|hours|min|mins|minutes?)$/.test(next)) {
    return { min: Math.round(Number(m[1]) * (next[0] === 'h' ? 60 : 1)), used: 2 };
  }
  return null;
}

function weekdayOf(t) {
  if (t in WD) return WD[t];
  if (t.endsWith('s') && t.slice(0, -1) in WD) return WD[t.slice(0, -1)];
  return null;
}

export function quickAdd(text, { now = new Date(), dateOrder = 'mdy', yearMode = 'future' } = {}) {
  const today = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;
  const raw = text.trim();
  const orig = raw.split(/\s+/).filter(Boolean);
  const norm = orig.map(clean);
  const used = new Array(orig.length).fill(false);
  const out = { title: '', type: 'task', date: null, time: null, durationMin: null, recur: null, course: null, priority: null, rank: null, weightPct: null, hints: [] };

  const take = (i, k) => {
    for (let j = i; j < i + k; j++) used[j] = true;
    // Swallow connector words directly in front ("due by fri", "at 3pm").
    let p = i - 1;
    while (p >= 0 && !used[p] && CONNECTORS.has(norm[p])) used[p--] = true;
    return k;
  };

  const setDate = (iso) => { if (iso && !out.date) out.date = iso; };

  for (let i = 0; i < orig.length; i++) {
    if (used[i]) continue;
    const rawTok = orig[i];
    const t = norm[i];
    const n1 = norm[i + 1];
    const n2 = norm[i + 2];

    let m = rawTok.match(/^!([a-e])([1-9])?[.,;]?$/i);
    if (m) { out.priority = m[1].toUpperCase(); out.rank = m[2] ? Number(m[2]) : null; take(i, 1); continue; }
    m = rawTok.match(/^#([\p{L}\p{N}_-]+)[.,;]?$/u);
    if (m) { out.course = m[1]; take(i, 1); continue; }

    // --- recurrence ---
    if (t === 'daily' || t === 'everyday') { out.recur = { freq: 'daily' }; take(i, 1); continue; }
    if (t === 'weekdays') { out.recur = { freq: 'weekdays' }; take(i, 1); continue; }
    if (t === 'weekly') { out.recur = { freq: 'weekly', days: [] }; take(i, 1); continue; }
    if (t === 'biweekly' || t === 'fortnightly') { out.recur = { freq: 'biweekly', days: [] }; take(i, 1); continue; }
    if (t === 'monthly') { out.recur = { freq: 'monthly' }; take(i, 1); continue; }
    if (t === 'every' || t === 'each') {
      let j = i + 1;
      let other = false;
      if (norm[j] === 'other') { other = true; j++; }
      const days = [];
      let k = j;
      while (k < orig.length) {
        const tk = norm[k];
        const wd = weekdayOf(tk);
        if (wd !== null) { days.push(wd); k++; continue; }
        if (tk in SHORT_DAYS || tk === 'tr') { days.push(...(SHORT_DAYS[tk] || [2, 4])); k++; continue; }
        if (tk.includes('/') && tk.split('/').every((p) => weekdayOf(p) !== null)) { days.push(...tk.split('/').map(weekdayOf)); k++; continue; }
        if ((tk === 'and' || tk === '&' || tk === ',') && days.length && k + 1 < orig.length && weekdayOf(norm[k + 1]) !== null) { k++; continue; }
        break;
      }
      if (days.length) {
        out.recur = { freq: other ? 'biweekly' : 'weekly', days: [...new Set(days)].sort() };
        take(i, k - i);
        i = k - 1;
        continue;
      }
      const unit = norm[j];
      const unitRecur = { day: { freq: 'daily' }, weekday: { freq: 'weekdays' }, weekdays: { freq: 'weekdays' },
        week: { freq: other ? 'biweekly' : 'weekly', days: [] }, month: { freq: 'monthly' } }[unit];
      if (unitRecur) { out.recur = unitRecur; take(i, j - i + 1); i = j; continue; }
    }
    // "tuesdays" repeats; "tues" and "thurs" are just short for the day.
    const plural = !(t in WD) && t.endsWith('s') && t.slice(0, -1) in WD;
    if (plural) { out.recur = { freq: 'weekly', days: [WD[t.slice(0, -1)]] }; take(i, 1); continue; }
    if (t in SHORT_DAYS) { out.recur = { freq: 'weekly', days: SHORT_DAYS[t] }; take(i, 1); continue; }

    // --- relative dates ---
    if (t === 'today' || t === 'tonight') { setDate(today); if (t === 'tonight' && !out.time) out.time = '20:00'; take(i, 1); continue; }
    if (['tomorrow', 'tmr', 'tmrw', 'tmw', 'tomorow', 'tommorow'].includes(t)) { setDate(addDays(today, 1)); take(i, 1); continue; }
    if (t === 'next' && n1 !== undefined) {
      const wd = weekdayOf(n1);
      // "next fri" means Friday of next week (Mon-Sun), never tomorrow.
      const nextMonday = upcomingWeekday(addDays(today, 1), 1);
      if (wd !== null) { setDate(addDays(nextMonday, (wd + 6) % 7)); take(i, 2); i++; continue; }
      if (n1 === 'week') { setDate(nextMonday); take(i, 2); i++; continue; }
    }
    if (t === 'this' && n1 === 'weekend') { setDate(upcomingWeekday(today, 6)); take(i, 2); i++; continue; }
    if (t === 'in' && n1 !== undefined) {
      const num = n1 === 'a' || n1 === 'an' ? 1 : Number(n1);
      const unit = n2 || '';
      if (Number.isInteger(num) && num > 0 && /^(days?|weeks?)$/.test(unit)) {
        setDate(addDays(today, unit.startsWith('week') ? num * 7 : num));
        take(i, 3); i += 2; continue;
      }
    }
    if (t in WD && !out.date) { setDate(upcomingWeekday(today, WD[t])); take(i, 1); continue; }

    // --- absolute dates ---
    m = t.match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/);
    if (m) { setDate(makeISO(+m[1], +m[2], +m[3])); take(i, 1); continue; }
    m = t.match(/^(\d{1,2})\/(\d{1,2})(?:\/(\d{2,4}))?$/);
    if (m) {
      let [a, b] = [Number(m[1]), Number(m[2])];
      const [mo, d] = dateOrder === 'dmy' ? [b, a] : [a, b];
      let iso;
      if (m[3]) {
        const y = m[3].length === 2 ? 2000 + Number(m[3]) : Number(m[3]);
        iso = makeISO(y, mo, d);
      } else {
        iso = resolveYearless(mo, d, today, yearMode);
      }
      if (iso) { setDate(iso); take(i, 1); continue; }
    }
    if (t in MONTHS && n1 !== undefined) {
      const dm = n1.match(/^(\d{1,2})(st|nd|rd|th)?$/);
      if (dm) {
        const yr = n2 && /^\d{4}$/.test(n2) ? Number(n2) : null;
        const iso = yr ? makeISO(yr, MONTHS[t], Number(dm[1])) : resolveYearless(MONTHS[t], Number(dm[1]), today, yearMode);
        if (iso) { setDate(iso); take(i, yr ? 3 : 2); i += yr ? 2 : 1; continue; }
      }
    }
    m = t.match(/^(\d{1,2})(st|nd|rd|th)?$/);
    // "3 sep" is a date, but not in "week 3 sep 15" (counter, then month-day) or "chapter 3 sep…".
    const counter = i > 0 && COUNTERS.has(norm[i - 1]);
    const monthDayNext = n2 !== undefined && /^\d{1,2}(st|nd|rd|th)?$/.test(n2);
    if (m && n1 in MONTHS && !counter && !monthDayNext) {
      const iso = resolveYearless(MONTHS[n1], Number(m[1]), today, yearMode);
      if (iso) { setDate(iso); take(i, 2); i++; continue; }
    }

    // --- times ---
    const range = parseRange(t);
    if (range) { out.time = range.time; out.durationMin = range.durationMin; take(i, 1); continue; }
    const clock = parseClock(t);
    if (clock && !out.time) { out.time = clock; take(i, 1); continue; }
    if (/^\d{1,2}(?::\d{2})?$/.test(t) && (n1 === 'am' || n1 === 'pm')) {
      const c = parseClock(t + n1);
      if (c) { out.time = c; take(i, 2); i++; continue; }
    }
    if (/^\d{1,2}$/.test(t) && i > 0 && (norm[i - 1] === 'at' || norm[i - 1] === '@') && !out.time) {
      const h = Number(t);
      if (h >= 1 && h <= 12) { out.time = `${pad(guessHour(h))}:00`; take(i, 1); continue; }
    }

    // --- share of the final grade: "25%", "(worth 20%)" ---
    m = t.match(/^(\d{1,3}(?:\.\d+)?)%$/);
    if (m && Number(m[1]) > 0 && Number(m[1]) <= 100) {
      out.weightPct = Number(m[1]);
      take(i, 1);
      if (i > 0 && !used[i - 1] && norm[i - 1] === 'worth') used[i - 1] = true;
      continue;
    }

    // --- duration / effort ---
    const dur = parseDuration(t, n1);
    if (dur && dur.min > 0) { out.durationMin = dur.min; take(i, dur.used); i += dur.used - 1; continue; }
  }

  // Leftover connector words at the end ("Lab report due") are noise.
  for (let i = orig.length - 1; i >= 0 && !used[i] && CONNECTORS.has(norm[i]) && norm[i] !== 'for'; i--) used[i] = true;

  let title = orig.filter((_, i) => !used[i]).join(' ').replace(/^[\s,;:–-]+|[\s,;:–-]+$/g, '');
  // bare: the text was nothing but dates, times and tags.
  out.bare = !title;
  if (!title) title = raw;
  out.title = title;
  out.type = detectType(raw);

  if (out.recur) {
    if ((out.recur.freq === 'weekly' || out.recur.freq === 'biweekly') && !out.recur.days.length) {
      out.recur.days = [weekday(out.date || today)];
    }
    if (!out.date) {
      if (out.recur.days) {
        const cands = out.recur.days.map((d) => upcomingWeekday(today, d)).sort();
        out.date = cands[0];
      } else if (out.recur.freq === 'weekdays') {
        let d = today;
        while (weekday(d) === 0 || weekday(d) === 6) d = addDays(d, 1);
        out.date = d;
      } else {
        out.date = today;
      }
    }
    // Repeating things with a time are almost always classes or meetings.
    if (out.type === 'task' && out.time) out.type = 'event';
  }
  if (out.time && !out.date) {
    const nowMin = now.getHours() * 60 + now.getMinutes();
    const [h, mi] = out.time.split(':').map(Number);
    out.date = h * 60 + mi >= nowMin ? today : addDays(today, 1);
  }
  // Something to attend needs a day. Without one it is something to do ("Buy a lab notebook",
  // "Call mum"); as an event it would show up nowhere.
  if (out.type === 'event' && !out.date) out.type = 'task';

  const low = raw.toLowerCase();
  if (/\b(i'?ll try|try to|trying to|attempt to)\b/.test(low)) out.hints.push('try');
  if (/\b(i wish|wish i)\b/.test(low)) out.hints.push('wish');
  if (/\b(have to|gotta|got to)\b/.test(low)) out.hints.push('haveTo');
  if (/\bproblems?\b/.test(low) && !/problem sets?/.test(low)) out.hints.push('problem');
  return out;
}
