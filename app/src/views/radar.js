import { h, bubble, pips, codeTag, sec, fmtMin, formLabel } from '../ui.js';
import { fmtShort, relDay, fmtInDays, weekday, minToTime, timeToMin } from '../dates.js';
import { radar, vitalFew, missedSessions } from '../agenda.js';
import { TIPS } from '../coach.js';
import { typeTag, stakeTag } from '../components.js';

const WD = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

function vitalRow(v, ctx) {
  const it = v.item;
  const behind = (it.sessions || []).filter((x) => !x.done && x.date < ctx.today).length;
  let status;
  if (v.status === 'short') status = h('span', { class: 'status bad' }, 'Not enough time');
  else if (v.status === 'behind') status = h('span', { class: 'status bad' }, 'Behind');
  else if (v.status === 'not-started') status = h('span', { class: 'status' }, `Starts ${relDay(v.startBy, ctx.today)}`);
  else if (v.status === 'no-plan') status = h('span', { class: 'status' }, 'No plan yet');
  else if (!v.done && v.startBy === ctx.today) status = h('span', { class: 'status warn' }, 'Start today');
  else status = h('span', { class: 'status ok' }, 'On track');
  return h('li', { class: 'vital', role: 'button', tabindex: '0', onclick: () => ctx.edit(it.id) },
    bubble(it.priority, { filled: false }),
    h('div', { class: 'min0' },
      h('h3', null, it.title),
      h('div', { class: 'meta' }, typeTag(it.type), stakeTag(it), codeTag(it.course))),
    h('div', { class: 'when' },
      h('div', { class: 'mono' }, `${fmtShort(it.date).toUpperCase()}${it.time ? ` ${it.time}` : ''}`),
      h('div', { class: 'mono muted' }, fmtInDays(it.date, ctx.today))),
    h('div', { class: 'prog' },
      v.total ? pips(v.total, v.done, { bad: behind, label: `${v.done} of ${v.total} sessions done` }) : null,
      v.total ? h('span', { class: 'mono muted' }, `${v.done}/${v.total}`) : null,
      status));
}

// Study load as half-hour bubbles against the daily budget; anything over the budget is inked red.
function loadPips(load, budget) {
  const slots = Math.max(1, Math.round(budget / 30));
  const used = Math.round(load / 30);
  const out = [];
  for (let i = 0; i < Math.max(slots, used); i++) out.push(bubble('', { size: 'sm', filled: i < used, cls: i >= slots ? 'over' : '' }));
  return h('span', { class: 'pips', role: 'img', 'aria-label': `${fmtMin(load)} of study planned, budget ${fmtMin(budget)}` }, out);
}

function dayBlock(d, ctx) {
  const lines = [];
  for (const ev of d.schedule) {
    const end = ev.time ? minToTime(timeToMin(ev.time) + (ev.durationMin || 60)) : null;
    lines.push(h('li', { role: 'button', tabindex: '0', onclick: () => ctx.edit(ev.id) },
      h('span', { class: 't' }, ev.time ? `${ev.time}` : 'all day'),
      h('span', { class: 'what' }, ev.type === 'exam' ? h('b', null, 'EXAM ') : ev.type === 'presentation' ? h('b', null, 'TALK ') : null, ev.title, end ? h('span', { class: 'muted' }, ` –${end}`) : null),
      codeTag(ev.course)));
  }
  for (const it of d.due) {
    lines.push(h('li', { role: 'button', tabindex: '0', onclick: () => ctx.edit(it.id) },
      h('span', { class: 't' }, it.time || 'due'),
      h('span', { class: 'what' }, h('b', null, it.type === 'reading' ? 'READ BY ' : 'DUE '), it.title, it.priority ? h('span', { class: 'mono muted' }, ` [${it.priority}]`) : null),
      codeTag(it.course)));
  }
  for (const st of d.starts) {
    lines.push(h('li', { class: 'start', role: 'button', tabindex: '0', onclick: () => ctx.edit(st.id) },
      h('span', { class: 't' }, 'start'), h('span', { class: 'what' }, st.title), h('span')));
  }
  for (const sd of d.study) {
    lines.push(h('li', { class: 'study', role: 'button', tabindex: '0', onclick: () => ctx.edit(sd.item.id) },
      h('span', { class: 't' }, fmtMin(sd.minutes)),
      h('span', { class: 'what' }, `Study: ${sd.item.title}${sd.count > 1 ? ` ×${sd.count}` : ''}`),
      h('span')));
  }
  const wd = weekday(d.date);
  return h('section', { class: `lday${d.date === ctx.today ? ' today' : ''}${wd === 0 || wd === 6 ? ' wknd' : ''}` },
    h('div', { class: 'date' },
      formLabel(d.date === ctx.today ? 'Today' : WD[wd]),
      h('span', { class: 'display num' }, String(Number(d.date.slice(8))))),
    h('div', { class: 'min0' },
      lines.length ? h('ul', null, lines) : h('p', { class: 'free' }, 'Free'),
      d.load ? h('div', { class: 'load' }, loadPips(d.load, ctx.s.settings.perDayMin),
        h('span', { class: 'mono muted' }, `${fmtMin(d.load)} / ${fmtMin(ctx.s.settings.perDayMin)}`)) : null));
}

export function renderRadar(ctx) {
  const { s, today } = ctx;
  const horizon = ctx.ui.radarDays || 14;
  const days = radar(s.items, today, horizon, s.settings.perDayMin);
  const vital = vitalFew(s.items, today);
  const missed = missedSessions(s.items, today);
  const over = days.filter((d) => d.over).length;
  const dueCount = days.reduce((a, d) => a + d.due.length, 0);
  const exams = days.reduce((a, d) => a + d.schedule.filter((e) => e.type === 'exam').length, 0);
  return h('div', { class: 'view radar' },
    h('header', { class: 'dayhead' },
      h('h1', { class: 'display page-title' }, 'Radar'),
      h('span', { class: 'mono muted' }, `Next ${horizon} days · ${dueCount} due · ${exams} exam${exams === 1 ? '' : 's'}`)),
    missed.length ? h('div', { class: 'box callout alert' },
      h('span', { class: 'form box-label' }, 'Behind'),
      h('p', null, `${missed.map((m) => m.item.title).join(', ')}. ${TIPS.missed}`),
      h('div', { class: 'btn-row' }, h('button', { class: 'btn sm', type: 'button', onclick: ctx.act.replanMissed }, 'Re-plan from today'))) : null,
    h('section', { class: 'part' },
      sec('The vital few', { count: vital.length, note: 'A and B work, next 6 weeks' }),
      vital.length ? h('ul', { class: 'rows' }, vital.map((v) => vitalRow(v, ctx)))
        : h('p', { class: 'empty' }, 'Lettered exams, presentations, deadlines and readings appear here with a bubble per study session.')),
    over ? h('div', { class: 'box callout alert' },
      h('span', { class: 'form box-label' }, `${over} day${over > 1 ? 's' : ''} over budget`),
      h('p', null, `More study is planned than your ${fmtMin(s.settings.perDayMin)} a day. Balance re-spreads everything so A’s get first claim on each day. If it still doesn’t fit, start earlier, raise the budget in Settings, or delegate or drop something.`),
      h('div', { class: 'btn-row' }, h('button', { class: 'btn primary', type: 'button', onclick: ctx.act.balance }, 'Balance my plan'))) : null,
    h('section', { class: 'part' },
      sec('Day by day', { note: 'Bubbles: half-hours of study vs. your budget' }),
      h('div', { class: 'ledger' }, days.map((d) => dayBlock(d, ctx)))),
    h('div', { class: 'btn-row' },
      h('button', { class: 'btn', type: 'button', onclick: () => { ctx.ui.radarDays = horizon === 14 ? 30 : 14; ctx.refresh(); } },
        horizon === 14 ? 'Show 30 days' : 'Show 14 days'),
      h('button', { class: 'btn quiet', type: 'button', onclick: ctx.act.balance }, 'Balance my plan')));
}

