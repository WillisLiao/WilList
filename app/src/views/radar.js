import { h, icon, fmtMin, courseChip } from '../ui.js';
import { fmtShort, fmtRelDay, relDay, fmtTime, fmtInDays, weekday } from '../dates.js';
import { radar, vitalFew, missedSessions } from '../agenda.js';
import { TIPS } from '../coach.js';
import { typeIcon } from '../components.js';

const STATUS = {
  'on-track': ['On track', 'ok'],
  'not-started': ['Starts', 'muted'],
  behind: ['Behind: re-plan', 'bad'],
  short: ['Not enough time', 'bad'],
  'no-plan': ['No plan yet', 'muted'],
};

function vitalCard(v, ctx) {
  const it = v.item;
  const pct = v.total ? Math.round((v.done / v.total) * 100) : 0;
  let [label, tone] = STATUS[v.status];
  if (v.status === 'not-started' && v.startBy) label = `Starts ${relDay(v.startBy, ctx.today)}`;
  if (v.status === 'on-track' && !v.done && v.startBy === ctx.today) [label, tone] = ['Start today', 'warn'];
  return h('li', { class: `vital l-${it.priority}`, role: 'button', tabindex: '0', onclick: () => ctx.edit(it.id) },
    h('div', { class: 'vital-top' },
      h('span', { class: `badge l-${it.priority}` }, it.priority),
      typeIcon(it.type),
      h('span', { class: 'vital-title' }, it.title),
      courseChip(it.course)),
    h('div', { class: 'vital-when' },
      `${fmtShort(it.date)}${it.time ? `, ${fmtTime(it.time)}` : ''} · ${fmtInDays(it.date, ctx.today)}`),
    v.total ? h('div', { class: 'bar', role: 'progressbar', 'aria-valuenow': String(pct), 'aria-valuemin': '0', 'aria-valuemax': '100', 'aria-label': `${v.done} of ${v.total} sessions done` },
      h('span', { style: { width: `${pct}%` } })) : null,
    h('div', { class: 'vital-foot' },
      v.total ? h('span', null, `${v.done}/${v.total} sessions`) : null,
      h('span', { class: `status ${tone}` }, label)));
}

function dayBlock(d, ctx) {
  const items = [];
  for (const ev of d.schedule) {
    items.push(h('li', { class: `ag t-${ev.type}`, role: 'button', tabindex: '0', onclick: () => ctx.edit(ev.id) },
      h('span', { class: 'ag-time' }, ev.time ? fmtTime(ev.time) : 'All day'),
      ev.type !== 'event' ? h('span', { class: `pill t-${ev.type}` }, ev.type === 'exam' ? 'Exam' : 'Presenting') : null,
      h('span', { class: 'ag-title' }, ev.title), courseChip(ev.course)));
  }
  for (const it of d.due) {
    items.push(h('li', { class: `ag due l-${it.priority}`, role: 'button', tabindex: '0', onclick: () => ctx.edit(it.id) },
      h('span', { class: 'ag-time' }, it.time ? fmtTime(it.time) : 'Due'),
      it.priority ? h('span', { class: `badge l-${it.priority}` }, it.priority) : null,
      h('span', { class: 'ag-title' }, it.type === 'reading' ? `Read by: ${it.title}` : `Due: ${it.title}`), courseChip(it.course)));
  }
  for (const st of d.starts) {
    items.push(h('li', { class: 'ag start', role: 'button', tabindex: '0', onclick: () => ctx.edit(st.id) },
      h('span', { class: 'ag-time' }, icon('play')),
      h('span', { class: 'ag-title' }, h('b', null, 'Start: '), st.title)));
  }
  for (const sd of d.study) {
    items.push(h('li', { class: `ag study l-${sd.item.priority}`, role: 'button', tabindex: '0', onclick: () => ctx.edit(sd.item.id) },
      h('span', { class: 'ag-time' }, fmtMin(sd.minutes)),
      h('span', { class: 'ag-title' }, `Work on ${sd.item.title}${sd.count > 1 ? ` ×${sd.count}` : ''}`)));
  }
  const budget = ctx.s.settings.perDayMin;
  const pct = Math.min(100, Math.round((d.load / budget) * 100));
  const isToday = d.date === ctx.today;
  const wknd = [0, 6].includes(weekday(d.date));
  return h('section', { class: `day${d.over ? ' over' : ''}${isToday ? ' is-today' : ''}${wknd ? ' wknd' : ''}` },
    h('div', { class: 'day-head' },
      h('h3', null, isToday ? 'Today' : fmtRelDay(d.date, ctx.today) === 'Tomorrow' ? 'Tomorrow' : fmtShort(d.date)),
      d.load ? h('span', { class: 'load', title: `${fmtMin(d.load)} planned study, budget ${fmtMin(budget)}` },
        h('span', { class: 'load-bar' }, h('span', { style: { width: `${pct}%` } })),
        `${fmtMin(d.load)}`) : null),
    items.length ? h('ul', { class: 'ag-list' }, items) : h('p', { class: 'free' }, 'Free'),
    d.over ? h('p', { class: 'over-note' }, icon('alert'), `Over your ${fmtMin(budget)} study budget.`) : null);
}

export function renderRadar(ctx) {
  const { s, today } = ctx;
  const horizon = ctx.ui.radarDays || 14;
  const days = radar(s.items, today, horizon, s.settings.perDayMin);
  const vital = vitalFew(s.items, today);
  const missed = missedSessions(s.items, today);
  const busiest = days.filter((d) => d.over).length;
  return h('div', { class: 'view radar' },
    h('header', { class: 'view-head' },
      h('h1', null, 'Radar'),
      h('p', { class: 'lede' }, 'Everything that matters, before it becomes urgent.')),
    missed.length ? h('section', { class: 'card warn' },
      h('p', null, icon('alert'), h('b', null, 'Behind on: '), missed.map((m) => m.item.title).join(', '), '. ', TIPS.missed),
      h('button', { class: 'btn', onclick: ctx.act.replanMissed }, 'Re-plan from today')) : null,
    h('section', { class: 'card' },
      h('div', { class: 'card-head' }, h('h3', null, 'The vital few'), h('span', { class: 'count' }, String(vital.length))),
      vital.length
        ? h('ul', { class: 'vital-list' }, vital.map((v) => vitalCard(v, ctx)))
        : h('p', { class: 'empty-note' }, 'Your A and B exams, presentations, deadlines and readings for the next 6 weeks appear here, each with its progress.')),
    busiest ? h('section', { class: 'card warn' },
      h('p', null, icon('alert'), h('b', null, `${busiest} day${busiest > 1 ? 's' : ''} over your ${fmtMin(s.settings.perDayMin)} study budget. `),
        'Balance re-spreads all upcoming work so A’s get first claim on each day. If days are still over after that, the work doesn’t fit: start earlier, raise your budget in Settings, or delegate or drop something.'),
      h('button', { class: 'btn primary', onclick: ctx.act.balance }, 'Balance my plan')) : null,
    h('div', { class: 'days' }, days.map((d) => dayBlock(d, ctx))),
    h('div', { class: 'btn-row center' },
      h('button', { class: 'btn', onclick: () => { ctx.ui.radarDays = horizon === 14 ? 30 : 14; ctx.refresh(); } },
        horizon === 14 ? 'Show 30 days' : 'Show 14 days')));
}

