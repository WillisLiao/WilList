// Bring a whole semester in at once: calendar files exported from Canvas,
// Moodle, Blackboard, Google or Outlook (.ics), and syllabus text pasted as-is.

import { quickAdd, detectType } from './parse.js';
import { addDays, diffDays, toISO, pad, weekday, weekStart, WEEKDAYS } from './dates.js';

const KEEP_TYPES = new Set(['exam', 'deadline', 'presentation', 'reading']);

// ---------------------------------------------------------------- .ics

export function parseICS(text) {
  const lines = String(text).replace(/\r?\n[ \t]/g, '').split(/\r?\n/);
  const comps = [];
  let cur = null;
  for (const line of lines) {
    if (!line) continue;
    if (/^BEGIN:(VEVENT|VTODO)$/i.test(line)) { cur = { kind: line.slice(6).toUpperCase(), props: {} }; continue; }
    if (/^END:(VEVENT|VTODO)$/i.test(line)) { if (cur) comps.push(cur); cur = null; continue; }
    if (!cur) continue;
    // NAME;PARAM=a;PARAM="b:c":VALUE — the first colon outside quotes ends the name part.
    let q = false;
    let split = -1;
    for (let i = 0; i < line.length; i++) {
      if (line[i] === '"') q = !q;
      else if (line[i] === ':' && !q) { split = i; break; }
    }
    if (split < 0) continue;
    const [name, ...rawParams] = line.slice(0, split).split(';');
    const params = {};
    for (const p of rawParams) {
      const eq = p.indexOf('=');
      if (eq > 0) params[p.slice(0, eq).toUpperCase()] = p.slice(eq + 1).replace(/^"|"$/g, '');
    }
    (cur.props[name.toUpperCase()] ||= []).push({ params, value: line.slice(split + 1) });
  }
  return comps;
}

function unescapeText(v) {
  return v.replace(/\\n/gi, '\n').replace(/\\([,;\\])/g, '$1');
}

function tzOffsetMs(date, tz) {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: tz, hourCycle: 'h23', year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', second: '2-digit',
  }).formatToParts(date);
  const get = (t) => Number(parts.find((p) => p.type === t).value);
  return Date.UTC(get('year'), get('month') - 1, get('day'), get('hour') % 24, get('minute'), get('second')) - date.getTime();
}

// ICS date or date-time → local { date, time } (time null for all-day).
export function icsDateTime(prop) {
  if (!prop) return null;
  const v = prop.value.trim();
  const m = v.match(/^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})?(Z)?)?$/);
  if (!m) return null;
  const [, y, mo, d, hh, mi, ss, z] = m;
  if (!hh || prop.params?.VALUE === 'DATE') return { date: `${y}-${mo}-${d}`, time: null };
  let local;
  if (z) {
    local = new Date(Date.UTC(+y, mo - 1, +d, +hh, +mi, +(ss || 0)));
  } else if (prop.params?.TZID) {
    try {
      const guess = Date.UTC(+y, mo - 1, +d, +hh, +mi, +(ss || 0));
      let inst = guess - tzOffsetMs(new Date(guess), prop.params.TZID);
      inst = guess - tzOffsetMs(new Date(inst), prop.params.TZID);
      local = new Date(inst);
    } catch {
      local = new Date(+y, mo - 1, +d, +hh, +mi); // unknown zone name: keep the wall time
    }
  } else {
    local = new Date(+y, mo - 1, +d, +hh, +mi);
  }
  return { date: toISO(local), time: `${pad(local.getHours())}:${pad(local.getMinutes())}` };
}

function durationProp(v) {
  const m = v?.match(/^P(?:(\d+)D)?T?(?:(\d+)H)?(?:(\d+)M)?/);
  if (!m) return null;
  return (Number(m[1] || 0) * 1440) + (Number(m[2] || 0) * 60) + Number(m[3] || 0) || null;
}

const BYDAY = { SU: 0, MO: 1, TU: 2, WE: 3, TH: 4, FR: 5, SA: 6 };

export function mapRRule(value, start) {
  const r = Object.fromEntries(value.split(';').map((kv) => kv.split('=')));
  const interval = Number(r.INTERVAL || 1);
  const until = r.UNTIL ? icsDateTime({ value: r.UNTIL, params: {} })?.date : null;
  const byday = r.BYDAY ? r.BYDAY.split(',').map((x) => BYDAY[x.slice(-2)]).filter((x) => x !== undefined) : [];
  const count = r.COUNT ? Number(r.COUNT) : null;
  let rec = null;
  if (r.FREQ === 'DAILY' && interval === 1) rec = { freq: 'daily' };
  if (r.FREQ === 'WEEKLY' && interval <= 2) {
    const days = [...new Set(byday.length ? byday : [weekday(start)])].sort();
    if (interval === 1 && days.join() === '1,2,3,4,5') rec = { freq: 'weekdays' };
    else rec = { freq: interval === 2 ? 'biweekly' : 'weekly', days };
  }
  if (r.FREQ === 'MONTHLY' && interval === 1 && !/\d/.test(r.BYDAY || '')) rec = { freq: 'monthly' };
  if (!rec) return null;
  if (until) rec.until = until;
  else if (count) {
    // Last day that still holds the final occurrence (inclusive end).
    const span = rec.freq === 'daily' ? count - 1
      : rec.freq === 'monthly' ? (count - 1) * 31 + 1
        : 7 * interval * Math.ceil(count / (rec.days?.length || 5)) - 1;
    rec.until = addDays(start, span);
  }
  return rec;
}

// "MATH 201 Fall 2026" → "MATH201"; anything else is shortened.
export function courseCode(s) {
  if (!s) return null;
  const m = s.match(/\b([A-Z]{2,5})[\s-]?(\d{2,4}[A-Z]?)\b/);
  if (m) return `${m[1]}${m[2]}`;
  const t = s.trim();
  return t.length > 24 ? `${t.slice(0, 23)}…` : t;
}

function stripHtml(s) {
  return s.replace(/<[^>]+>/g, ' ').replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&').replace(/[ \t]+/g, ' ').trim();
}

export function icsToFields(comp, today) {
  const p = (k) => comp.props[k]?.[0];
  const summary = unescapeText(p('SUMMARY')?.value || '').trim();
  if (!summary) return { skip: 'empty' };
  // LMS noise: Moodle "Quiz 3 opens" and similar availability windows.
  if (/\b(opens|is open|available)$/i.test(summary)) return { skip: 'noise' };
  let title = summary;
  let course = null;
  const bracket = title.match(/^(.*?)\s*\[([^\]]+)\]\s*$/); // Canvas: "Essay 2 [HIST 150 Fall]"
  if (bracket) { title = bracket[1]; course = courseCode(bracket[2]); }
  title = title.replace(/^(?:assignment|assessment)\s+due:\s*/i, '').replace(/\s+(?:is due|closes|due)\.?$/i, '').trim();
  const cats = p('CATEGORIES') ? unescapeText(p('CATEGORIES').value).split(',') : [];
  if (!course && cats[0]) course = courseCode(cats[0]);

  const start = icsDateTime(p('DUE')) || icsDateTime(p('DTSTART'));
  if (!start) return { skip: 'nodate' };
  const end = icsDateTime(p('DTEND'));
  let durationMin = durationProp(p('DURATION')?.value);
  if (!durationMin && start.time && end?.time) {
    durationMin = diffDays(start.date, end.date) * 1440 +
      (Number(end.time.slice(0, 2)) * 60 + Number(end.time.slice(3))) - (Number(start.time.slice(0, 2)) * 60 + Number(start.time.slice(3)));
  }
  const recur = p('RRULE') ? mapRRule(p('RRULE').value, start.date) : null;
  const skips = (comp.props.EXDATE || []).flatMap((x) => x.value.split(',').map((v) => icsDateTime({ value: v, params: x.params })?.date)).filter(Boolean);

  if (recur?.until && diffDays(today, recur.until) < 0) return { skip: 'past' };
  if (!recur && diffDays(today, start.date) < 0) return { skip: 'past' };
  if (comp.kind === 'VTODO' && /COMPLETED/i.test(p('STATUS')?.value || '')) return { skip: 'done' };

  let type = detectType(title);
  const uid = p('UID')?.value || '';
  const assignment = comp.kind === 'VTODO' || /assignment|submission/i.test(uid);
  if (assignment && (type === 'task' || type === 'event')) type = 'deadline';
  if (type === 'task') {
    if (recur || (durationMin && durationMin >= 15)) type = 'event';
    else if (start.time) type = 'deadline';
  }
  const desc = stripHtml(unescapeText(p('DESCRIPTION')?.value || ''));
  return {
    fields: {
      externalId: uid ? `ics:${uid}` : null,
      title: title || summary,
      type,
      course,
      date: start.date,
      time: start.time,
      durationMin: type === 'event' ? (durationMin > 0 ? durationMin : 60) : null,
      recur: type === 'event' || type === 'task' ? recur : null,
      skips,
      notes: desc.length > 400 ? `${desc.slice(0, 400)}…` : desc,
    },
  };
}

export function importICS(text, today) {
  const comps = parseICS(text);
  const out = { items: [], past: 0, ignored: 0 };
  for (const c of comps) {
    const r = icsToFields(c, today);
    if (r.fields) out.items.push(r.fields);
    else if (r.skip === 'past' || r.skip === 'done') out.past++;
    else out.ignored++;
  }
  return out;
}

// ---------------------------------------------------------------- syllabus text

const WD_NAMES = new Map([...WEEKDAYS.map((d, i) => [d, i]),
  ['monday', 1], ['tuesday', 2], ['wednesday', 3], ['thursday', 4], ['friday', 5], ['saturday', 6], ['sunday', 0], ['tues', 2], ['thur', 4], ['thurs', 4]]);

function cleanTitle(t) {
  const out = t.replace(/\(\s*\)/g, '')
    .replace(/^\s*(?:week|wk)\s*\d{1,2}\b[\s:.,–—-]*/i, '')
    .replace(/^[\s:;,.–—•*·-]+|[\s:;,.–—•*·-]+$/g, '')
    .replace(/\s{2,}/g, ' ')
    .trim();
  return out.charAt(0).toUpperCase() + out.slice(1);
}

// One candidate per date-bearing line (or part of a line split by ; | or tabs).
// Exams, deadlines, presentations and readings are pre-selected; other dated
// lines (lecture topics, holidays) are offered unselected.
export function parseSyllabus(text, { now = new Date(), dateOrder = 'mdy', course = null, week1 = null } = {}) {
  const today = toISO(now);
  const rows = [];
  let past = 0;
  const seen = new Set();
  for (const rawLine of String(text).split(/\r?\n/)) {
    const line = rawLine.replace(/^\s*(?:[-*•·]|\d{1,2}[.)])\s+/, '').trim();
    if (line.length < 4) continue;
    let carryDate = null;
    for (const part of line.split(/\t+|\s\|\s|;\s*/)) {
      if (!part.trim()) continue;
      const p = quickAdd(part, { now, dateOrder, yearMode: 'nearest' });
      let date = p.date;
      let approx = false;
      // "Week 9 Thu" means Thursday of week 9, not the coming Thursday.
      const wk = week1 && part.match(/\b(?:week|wk)\s*(\d{1,2})\b/i);
      const explicit = /\b\d{1,2}\/\d{1,2}\b|\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+\d/i.test(part);
      if (wk && !explicit) {
        const monday = addDays(weekStart(week1), (Number(wk[1]) - 1) * 7);
        const named = part.toLowerCase().match(/\b(mon(?:day)?|tue(?:s|sday)?|wed(?:nesday)?|thu(?:r|rs|rsday)?|fri(?:day)?|sat(?:urday)?|sun(?:day)?)\b/);
        if (named) {
          const wd = WD_NAMES.get(named[1]) ?? WD_NAMES.get(named[1].slice(0, 3));
          date = addDays(monday, (wd + 6) % 7);
        } else {
          date = monday;
          approx = true;
        }
      }
      if (!date && carryDate) date = carryDate;
      if (!date) continue;
      carryDate = date;
      if (diffDays(today, date) < 0) { past++; continue; }
      if (p.bare) continue;
      const title = cleanTitle(p.title);
      if (!title || /^(due|tbd|tba|no class|none)$/i.test(title)) continue;
      const type = p.type === 'task' && /\bdue\b/i.test(part) ? 'deadline' : p.type;
      const key = `${title.toLowerCase()}|${date}`;
      if (seen.has(key)) continue;
      seen.add(key);
      rows.push({
        keep: KEEP_TYPES.has(type),
        approx,
        line: rawLine.trim(),
        fields: {
          title, type, date, time: p.time, course: p.course || course || null,
          weightPct: p.weightPct, durationMin: type === 'event' ? p.durationMin : null,
          effortMin: type !== 'event' && p.durationMin ? p.durationMin : null,
        },
      });
    }
  }
  return { rows, past };
}

// ---------------------------------------------------------------- merge

// The calendar is the source of truth for names and dates; your letter, type and plan stay yours.
const SAME_KEYS = ['title', 'date', 'time', 'course'];

// Works out what an import would change, so the user can confirm first.
// Calendar items are matched on their calendar ID, so re-importing updates them;
// pasted items are matched on title and date.
export function planImport(items, incoming) {
  const adds = [];
  const updates = [];
  let same = 0;
  for (const inc of incoming) {
    const existing = inc.externalId
      ? items.find((it) => it.externalId === inc.externalId)
      : items.find((it) => it.date === inc.date && it.title.trim().toLowerCase() === inc.title.trim().toLowerCase());
    if (!existing) { adds.push(inc); continue; }
    const patch = {};
    for (const k of SAME_KEYS) if ((inc[k] ?? null) !== (existing[k] ?? null) && inc.externalId) patch[k] = inc[k] ?? null;
    if (inc.externalId && JSON.stringify(inc.recur || null) !== JSON.stringify(existing.recur || null)) patch.recur = inc.recur || null;
    if (Object.keys(patch).length) updates.push({ id: existing.id, title: existing.title, patch });
    else same++;
  }
  return { adds, updates, same };
}
