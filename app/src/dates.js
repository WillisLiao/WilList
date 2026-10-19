// Dates are stored as local "YYYY-MM-DD" strings and times as "HH:MM".
// Keeping them as plain strings avoids timezone drift when data is saved,
// exported and loaded again on another device.

export const DAY_MS = 86400000;
export const WEEKDAYS = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];

export const pad = (n) => String(n).padStart(2, '0');

export function toISO(d) {
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

export function fromISO(iso) {
  const [y, m, d] = iso.split('-').map(Number);
  return new Date(y, m - 1, d);
}

export function todayISO(now = new Date()) {
  return toISO(now);
}

export function nowHHMM(now = new Date()) {
  return `${pad(now.getHours())}:${pad(now.getMinutes())}`;
}

export function addDays(iso, n) {
  const d = fromISO(iso);
  d.setDate(d.getDate() + n);
  return toISO(d);
}

// Whole days from a to b (positive when b is later). UTC math sidesteps DST.
export function diffDays(a, b) {
  const [ay, am, ad] = a.split('-').map(Number);
  const [by, bm, bd] = b.split('-').map(Number);
  return Math.round((Date.UTC(by, bm - 1, bd) - Date.UTC(ay, am - 1, ad)) / DAY_MS);
}

export function weekday(iso) {
  return fromISO(iso).getDay();
}

// Monday of the week containing iso.
export function weekStart(iso) {
  const wd = weekday(iso);
  return addDays(iso, wd === 0 ? -6 : 1 - wd);
}

export function isValidISO(iso) {
  if (typeof iso !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(iso)) return false;
  return toISO(fromISO(iso)) === iso;
}

export function timeToMin(hhmm) {
  if (!hhmm) return null;
  const [h, m] = hhmm.split(':').map(Number);
  return h * 60 + m;
}

export function minToTime(min) {
  const m = ((min % 1440) + 1440) % 1440;
  return `${pad(Math.floor(m / 60))}:${pad(m % 60)}`;
}

const timeFmt = new Intl.DateTimeFormat(undefined, { hour: 'numeric', minute: '2-digit' });
const shortFmt = new Intl.DateTimeFormat(undefined, { weekday: 'short', month: 'short', day: 'numeric' });
const longFmt = new Intl.DateTimeFormat(undefined, { weekday: 'long', month: 'long', day: 'numeric' });
const wdFmt = new Intl.DateTimeFormat(undefined, { weekday: 'short' });
const mdFmt = new Intl.DateTimeFormat(undefined, { month: 'short', day: 'numeric' });

export function fmtTime(hhmm) {
  if (!hhmm) return '';
  const [h, m] = hhmm.split(':').map(Number);
  return timeFmt.format(new Date(2000, 0, 1, h, m));
}

export function fmtLong(iso) {
  return longFmt.format(fromISO(iso));
}

export function fmtShort(iso) {
  return shortFmt.format(fromISO(iso));
}

// "Today", "Tomorrow", "Fri" (within a week) or "Oct 24".
export function fmtRelDay(iso, today) {
  const n = diffDays(today, iso);
  if (n === 0) return 'Today';
  if (n === 1) return 'Tomorrow';
  if (n === -1) return 'Yesterday';
  if (n > 1 && n < 7) return wdFmt.format(fromISO(iso));
  return mdFmt.format(fromISO(iso));
}

// fmtRelDay for use mid-sentence: "start today", "start Fri", "start Oct 24".
export function relDay(iso, today) {
  const s = fmtRelDay(iso, today);
  return s === 'Today' || s === 'Tomorrow' || s === 'Yesterday' ? s.toLowerCase() : s;
}

export function fmtInDays(iso, today) {
  const n = diffDays(today, iso);
  if (n === 0) return 'today';
  if (n === 1) return 'tomorrow';
  if (n === -1) return 'yesterday';
  if (n < 0) return `${-n} days ago`;
  if (n < 14) return `in ${n} days`;
  return `in ${Math.round(n / 7)} weeks`;
}

// Detect whether the user's locale writes 12/31 or 31/12.
export function localeDateOrder() {
  try {
    const parts = new Intl.DateTimeFormat(undefined).formatToParts(new Date(2000, 11, 31));
    const order = parts.filter((p) => p.type === 'day' || p.type === 'month').map((p) => p.type);
    return order[0] === 'day' ? 'dmy' : 'mdy';
  } catch {
    return 'mdy';
  }
}
