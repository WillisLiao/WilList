// .ics export so phone calendars (Apple, Google, Outlook) can deliver real
// reminders even when WilList is closed. Times are "floating" local times.

import { addDays, minToTime, timeToMin } from './dates.js';
import { isPast } from './agenda.js';

const BYDAY = ['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA'];

function esc(s) {
  return String(s ?? '').replace(/\\/g, '\\\\').replace(/;/g, '\\;').replace(/,/g, '\\,').replace(/\r?\n/g, '\\n');
}

// RFC 5545 lines must be folded at 75 octets.
function fold(line) {
  const enc = new TextEncoder();
  if (enc.encode(line).length <= 75) return line;
  const parts = [];
  let cur = '';
  for (const ch of line) {
    const limit = parts.length ? 74 : 75;
    if (enc.encode(cur + ch).length > limit) { parts.push(cur); cur = ''; }
    cur += ch;
  }
  parts.push(cur);
  return parts.join('\r\n ');
}

const dateVal = (iso) => iso.replace(/-/g, '');
const dtVal = (iso, hhmm) => `${dateVal(iso)}T${hhmm.replace(':', '')}00`;

function stamp(now) {
  return now.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '');
}

function rrule(recur) {
  if (!recur) return null;
  const until = recur.until ? `;UNTIL=${dateVal(recur.until)}T235959` : '';
  switch (recur.freq) {
    case 'daily': return `RRULE:FREQ=DAILY${until}`;
    case 'weekdays': return `RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR${until}`;
    case 'weekly': return `RRULE:FREQ=WEEKLY;BYDAY=${recur.days.map((d) => BYDAY[d]).join(',')}${until}`;
    case 'biweekly': return `RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=${recur.days.map((d) => BYDAY[d]).join(',')}${until}`;
    case 'monthly': return `RRULE:FREQ=MONTHLY${until}`;
    default: return null;
  }
}

function alarm(trigger, text) {
  return ['BEGIN:VALARM', 'ACTION:DISPLAY', `DESCRIPTION:${esc(text)}`, `TRIGGER:${trigger}`, 'END:VALARM'];
}

function vevent({ uid, now, title, date, time, durationMin, recur, desc, alarms = [] }) {
  const lines = ['BEGIN:VEVENT', `UID:${uid}@willist`, `DTSTAMP:${stamp(now)}`, `SUMMARY:${esc(title)}`];
  if (time) {
    const end = timeToMin(time) + (durationMin || 60);
    const endDate = end >= 1440 ? addDays(date, 1) : date;
    lines.push(`DTSTART:${dtVal(date, time)}`, `DTEND:${dtVal(endDate, minToTime(end))}`);
  } else {
    lines.push(`DTSTART;VALUE=DATE:${dateVal(date)}`, `DTEND;VALUE=DATE:${dateVal(addDays(date, 1))}`);
  }
  const rr = rrule(recur);
  if (rr) lines.push(rr);
  if (desc) lines.push(`DESCRIPTION:${esc(desc)}`);
  for (const a of alarms) lines.push(...a);
  lines.push('END:VEVENT');
  return lines;
}

const KIND = { exam: 'Exam', presentation: 'Presentation', deadline: 'Due', reading: 'Read by', task: 'Task' };

export function buildICS(items, { today, now = new Date(), includeSessions = true } = {}) {
  const out = ['BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//WilList//Student planner//EN', 'CALSCALE:GREGORIAN', 'X-WR-CALNAME:WilList'];
  for (const it of items) {
    if (!it.date || it.priority === 'E' || isPast(it, today) || (it.done && !it.recur)) continue;
    const letter = it.priority ? `[${it.priority}] ` : '';
    const course = it.course ? ` · ${it.course}` : '';
    if (it.type === 'event') {
      out.push(...vevent({ uid: it.id, now, title: `${it.title}${course}`, date: it.date, time: it.time,
        durationMin: it.durationMin, recur: it.recur, desc: it.notes,
        alarms: it.time ? [alarm('-PT15M', it.title)] : [] }));
      continue;
    }
    if (it.recur) {
      out.push(...vevent({ uid: it.id, now, title: `${letter}${it.title}${course}`, date: it.date, time: it.time,
        durationMin: 30, recur: it.recur, desc: it.notes, alarms: [alarm(it.time ? '-PT10M' : 'PT9H', it.title)] }));
      continue;
    }
    const big = it.type === 'exam' || it.type === 'presentation';
    const alarms = it.time
      ? [alarm('-P1D', `${KIND[it.type]} tomorrow: ${it.title}`), alarm(big ? '-PT1H' : '-PT3H', it.title)]
      : [alarm('-PT15H', `${KIND[it.type]} tomorrow: ${it.title}`)];
    out.push(...vevent({ uid: it.id, now, title: `${letter}${KIND[it.type] || ''}: ${it.title}${course}`,
      date: it.date, time: it.time, durationMin: big ? (it.durationMin || 90) : 15, desc: it.notes, alarms }));
    if (!includeSessions) continue;
    const open = (it.sessions || []).filter((s) => !s.done && s.date >= today);
    const first = (it.sessions || []).find((s) => !s.done);
    for (const s of open) {
      const isStart = first && s.id === first.id && !(it.sessions || []).some((x) => x.done);
      out.push(...vevent({ uid: `${it.id}-${s.id}`, now,
        title: `${isStart ? 'START ' : ''}${it.title}: ${s.label} (${s.minutes}m)`,
        date: s.date, time: null, desc: `${KIND[it.type]} ${it.date}. Planned by WilList.`,
        alarms: isStart ? [alarm('PT9H', `Start today: ${it.title}`)] : [] }));
    }
  }
  out.push('END:VCALENDAR');
  return out.map(fold).join('\r\n') + '\r\n';
}
