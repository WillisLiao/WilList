import { h, icon, rank, sec, fmtMin, band, progress, openSheet } from '../ui.js';
import { fmtShort, relDay, diffDays, weekday, minToTime, timeToMin } from '../dates.js';
import { radar, vitalFew, missedSessions } from '../agenda.js';
import { weekStats, calibrations } from '../insights.js';

const WD = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const DAYS = 14;

function nudge(cls, ic, text, label, onclick) {
  return h('div', { class: `banner ${cls}` },
    h('span', { class: 'bi' }, icon(ic)), h('b', null, text),
    h('button', { class: 'btn sm primary', type: 'button', onclick }, label));
}

// Everything on one day, in a sheet: classes, what's due, what to study.
function openDay(d, ctx) {
  const lines = [];
  for (const ev of d.schedule) {
    const end = ev.time ? minToTime(timeToMin(ev.time) + (ev.durationMin || 60)) : null;
    lines.push(h('li', { role: 'button', tabindex: '0', onclick: () => { close(); ctx.edit(ev.id); } },
      h('span', { class: 't' }, ev.time ? `${ev.time}–${end}` : 'all day'),
      h('span', { class: 'what' }, ev.type === 'exam' ? h('b', null, 'Exam: ') : ev.type === 'presentation' ? h('b', null, 'Present: ') : null, ev.title)));
  }
  for (const it of d.due) {
    lines.push(h('li', { role: 'button', tabindex: '0', onclick: () => { close(); ctx.edit(it.id); } },
      h('span', { class: 't' }, it.time || 'due'),
      h('span', { class: 'what' }, it.priority ? rank(it.priority) : null, ' ', it.title)));
  }
  for (const sd of d.study) {
    lines.push(h('li', { class: 'study', role: 'button', tabindex: '0', onclick: () => { close(); ctx.edit(sd.item.id); } },
      h('span', { class: 't' }, fmtMin(sd.minutes)), h('span', { class: 'what' }, `Study: ${sd.item.title}`)));
  }
  const title = `${d.date === ctx.today ? 'Today' : WD[weekday(d.date)]} ${fmtShort(d.date)}`;
  const close = openSheet(title, lines.length ? h('ul', { class: 'day-lines' }, lines) : h('p', { class: 'empty' }, 'Free.'));
}

// One column per day: what's due on top, study as a bar, the daily budget as a dashed line.
function chart(days, ctx) {
  const budget = ctx.s.settings.perDayMin || 120;
  const top = Math.max(budget * 1.5, ...days.map((d) => d.load));
  const pct = (m) => Math.round((m / top) * 1000) / 10;
  return h('div', { class: 'chart-wrap' },
    h('div', { class: `chart n${days.length}`, style: { '--n': String(days.length), '--b': String(pct(budget)) }, role: 'group', 'aria-label': `Study planned per day, budget ${fmtMin(budget)}` },
      h('div', { class: 'budget', 'aria-hidden': 'true' }),
      days.map((d) => {
        const wd = weekday(d.date);
        const exams = d.schedule.filter((e) => e.type === 'exam' || e.type === 'presentation');
        const marks = [...exams.map(() => h('i', { class: 'exam' })), ...d.due.map((it) => h('i', { class: it.priority === 'A' ? 'a' : null }))].slice(0, 3);
        const over = Math.max(0, d.load - budget);
        const base = d.load - over;
        return h('button', { class: `day-col${d.date === ctx.today ? ' today' : ''}`, type: 'button',
          'aria-label': `${WD[wd]} ${Number(d.date.slice(8))}: ${fmtMin(d.load)} study${d.due.length + exams.length ? `, ${d.due.length + exams.length} due` : ''}`, onclick: () => openDay(d, ctx) },
          h('span', { class: 'marks', 'aria-hidden': 'true' }, marks),
          h('span', { class: 'stack', 'aria-hidden': 'true' },
            over ? h('i', { class: 'over', style: { height: `${pct(over)}%` } }) : null,
            base ? h('i', { style: { height: `${pct(base)}%` } }) : h('i', { class: 'none' })),
          h('span', { class: 'lbl', 'aria-hidden': 'true' }, h('span', null, WD[wd][0]), h('b', null, String(Number(d.date.slice(8))))));
      })),
    h('div', { class: 'legend', 'aria-hidden': 'true' },
      h('span', null, h('i', { class: 'load' }), 'study'),
      h('span', null, h('i', { class: 'line' }), `${fmtMin(budget)} budget`),
      h('span', null, h('i', { class: 'exam' }), 'exam'),
      h('span', null, h('i', { class: 'a' }), 'due')));
}

function vitalCard(v, ctx) {
  const it = v.item;
  const n = diffDays(ctx.today, it.date);
  let status = 'on track';
  let cls = 'ok';
  if (v.status === 'short') { status = 'not enough time'; cls = 'bad'; } else if (v.status === 'behind') { status = 'behind'; cls = 'bad'; } else if (v.status === 'not-started') { status = `starts ${relDay(v.startBy, ctx.today)}`; cls = ''; } else if (v.status === 'no-plan') { status = ''; cls = ''; } else if (!v.done && v.startBy === ctx.today) { status = 'start today'; cls = 'warn'; }
  const canPull = it.priority === 'A' && v.status === 'not-started' && n > 3;
  return h('li', { class: 'vital', role: 'button', tabindex: '0', onclick: () => ctx.edit(it.id), onkeydown: (e) => { if (e.key === 'Enter') ctx.edit(it.id); } },
    h('div', { class: `countdown${n <= 2 ? ' soon' : ''}` }, h('b', null, String(n)), h('span', null, n === 1 ? 'day' : 'days')),
    h('div', { class: 'body' },
      h('h3', null, rank(it.priority), it.title),
      h('div', { class: 'progress-row' },
        v.total ? progress(v.done, v.total, { warn: cls === 'bad', label: `${v.done}/${v.total}` }) : null,
        status ? h('span', { class: `status ${cls}` }, status) : null,
        canPull ? h('button', { class: 'btn sm', type: 'button', onclick: (e) => { e.stopPropagation(); ctx.act.pullForward(it.id); } }, 'Do one today') : null)));
}

export function renderRadar(ctx) {
  const { s, today } = ctx;
  const days = radar(s.items, today, DAYS, s.settings.perDayMin);
  const vital = vitalFew(s.items, today);
  const missed = missedSessions(s.items, today);
  const over = days.filter((d) => d.over).length;
  const dueCount = days.reduce((a, d) => a + d.due.length, 0);
  const exams = days.reduce((a, d) => a + d.schedule.filter((e) => e.type === 'exam').length, 0);
  const stats = weekStats(s, today);
  const cal = calibrations(s.log, s.settings.calib)[0];
  const stale = s.items.filter((it) => ['C', 'D', 'E'].includes(it.priority) && !it.done && it.type !== 'event' && it.createdAt && diffDays(it.createdAt, today) >= 14);
  return h('div', { class: 'view radar' },
    band('Ahead',
      h('div', { class: 'band-top' },
        h('div', { class: 'min0' },
          h('h1', { class: 'display' }, `Next ${DAYS} days`),
          h('p', { class: 'sub' }, `${dueCount} due · ${exams} exam${exams === 1 ? '' : 's'}`))),
      chart(days, ctx)),
    h('div', { class: 'col page' },
      missed.length ? nudge('alert', 'alert', 'Behind on study', 'Re-plan', ctx.act.replanMissed) : null,
      over ? nudge('alert', 'stack', `${over} day${over > 1 ? 's' : ''} over budget`, 'Balance', ctx.act.balance) : null,
      cal ? nudge('', 'clock', `${cal.label} takes you ${cal.ratio}× longer`, 'Adjust', () => ctx.act.setCalib(cal.type, cal.ratio)) : null,
      stale.length ? nudge('', 'stack', `${stale.length} old C–E item${stale.length > 1 ? 's' : ''}`, 'Review', () => openStale(stale, ctx)) : null,
      h('section', { class: 'part' },
        sec('Coming up'),
        vital.length ? h('ul', { class: 'vital-list' }, vital.map((v) => vitalCard(v, ctx)))
          : h('p', { class: 'empty' }, 'Lettered exams and deadlines show up here.')),
      h('section', { class: 'part' },
        sec('Last 7 days'),
        h('div', { class: 'stats' },
          h('div', { class: 'stat' }, h('b', null, fmtMin(stats.focusMin)), h('span', null, 'focused')),
          h('div', { class: 'stat' }, h('b', null, String(stats.aDone)), h('span', null, 'A’s done')),
          h('div', { class: 'stat' }, h('b', null, String(stats.done)), h('span', null, 'all done'))))));
}

// "Do first things first, and second things not at all."
function openStale(items, ctx) {
  let close = null;
  const list = h('ul', { class: 'rows' }, items.map((it) => h('li', { class: 'item plain' },
    h('div', { class: 'item-main' }, h('div', { class: 'item-title' }, rank(it.priority), it.title)),
    h('div', { class: 'btn-row' },
      h('button', { class: 'btn sm', type: 'button', onclick: (e) => { ctx.act.keep(it.id); e.target.closest('li').remove(); if (!list.children.length) close(); } }, 'Keep'),
      h('button', { class: 'btn sm danger', type: 'button', onclick: (e) => { ctx.act.remove(it.id); e.target.closest('li').remove(); if (!list.children.length) close(); } }, 'Drop')))));
  close = openSheet('Still worth it?', list);
}
