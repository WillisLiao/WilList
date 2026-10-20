import { h, icon, rank, tag, meta, sec, fmtMin, band, segmented, progress, TYPE_META } from '../ui.js';
import { fmtShort, relDay, diffDays, weekday, minToTime, timeToMin } from '../dates.js';
import { radar, vitalFew, missedSessions } from '../agenda.js';
import { TIPS } from '../coach.js';
import { stakeTag } from '../components.js';

const WD = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

function jumpTo(date) {
  const el = document.getElementById(`d-${date}`);
  if (!el) return;
  el.scrollIntoView({ behavior: window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth', block: 'start' });
  el.classList.remove('flash');
  void el.offsetWidth;
  el.classList.add('flash');
}

// One column per day: what's due on top, study load as a bar, the budget as a dashed line.
function chart(days, ctx) {
  const budget = ctx.s.settings.perDayMin || 120;
  const top = Math.max(budget * 1.5, ...days.map((d) => d.load));
  const pct = (m) => Math.round((m / top) * 1000) / 10;
  const total = days.reduce((a, d) => a + d.load, 0);
  return h('div', { class: 'chart-wrap' },
    h('div', { class: `chart n${days.length}`, style: { '--n': String(days.length), '--b': String(pct(budget)) }, role: 'img',
      'aria-label': `Study planned per day for the next ${days.length} days, ${fmtMin(total)} in total, against a budget of ${fmtMin(budget)} a day.` },
      h('div', { class: 'budget', 'aria-hidden': 'true' }, h('span', null, `${fmtMin(budget)} budget`)),
      days.map((d) => {
        const wd = weekday(d.date);
        const marks = [
          ...d.schedule.filter((e) => e.type === 'exam' || e.type === 'presentation').map(() => h('i', { class: 'exam' })),
          ...d.due.map((it) => h('i', { class: it.priority === 'A' ? 'a' : null })),
        ].slice(0, 3);
        const over = Math.max(0, d.load - budget);
        const base = d.load - over;
        const n = d.due.length + d.schedule.filter((e) => e.type === 'exam' || e.type === 'presentation').length;
        return h('button', { class: `day-col${d.date === ctx.today ? ' today' : ''}${wd === 0 || wd === 6 ? ' wknd' : ''}`, type: 'button',
          'aria-label': `${WD[wd]} ${Number(d.date.slice(8))}: ${fmtMin(d.load)} of study${n ? `, ${n} due` : ''}`, onclick: () => jumpTo(d.date) },
          h('span', { class: 'marks', 'aria-hidden': 'true' }, marks),
          h('span', { class: 'stack', 'aria-hidden': 'true' },
            over ? h('i', { class: 'over', style: { height: `${pct(over)}%` } }) : null,
            base ? h('i', { style: { height: `${pct(base)}%` } }) : h('i', { class: 'none' })),
          h('span', { class: 'lbl', 'aria-hidden': 'true' }, h('span', null, WD[wd][0]), h('b', null, String(Number(d.date.slice(8))))));
      })),
    h('div', { class: 'legend', 'aria-hidden': 'true' },
      h('span', null, h('i', { class: 'load' }), 'Study planned'),
      h('span', null, h('i', { class: 'line' }), 'Daily budget'),
      h('span', null, h('i', { class: 'exam' }), 'Exam or talk'),
      h('span', null, h('i', { class: 'a' }), 'A due'),
      h('span', null, h('i'), 'Other due')));
}

function vitalCard(v, ctx) {
  const it = v.item;
  const n = diffDays(ctx.today, it.date);
  const behind = (it.sessions || []).filter((x) => !x.done && x.date < ctx.today).length;
  let status;
  if (v.status === 'short') status = h('span', { class: 'status bad' }, 'Not enough time planned');
  else if (v.status === 'behind') status = h('span', { class: 'status bad' }, `Behind by ${behind} session${behind > 1 ? 's' : ''}`);
  else if (v.status === 'not-started') status = h('span', { class: 'status' }, `Starts ${relDay(v.startBy, ctx.today)}`);
  else if (v.status === 'no-plan') status = h('span', { class: 'status' }, 'No study plan');
  else if (!v.done && v.startBy === ctx.today) status = h('span', { class: 'status warn' }, 'Start today');
  else status = h('span', { class: 'status ok' }, 'On track');
  return h('li', { class: 'vital', role: 'button', tabindex: '0', onclick: () => ctx.edit(it.id), onkeydown: (e) => { if (e.key === 'Enter') ctx.edit(it.id); } },
    h('div', { class: `countdown${n <= 2 ? ' soon' : ''}`, 'aria-label': n === 0 ? 'today' : `in ${n} days` },
      h('b', null, String(n)), h('span', null, n === 1 ? 'day' : 'days')),
    h('div', { class: 'body' },
      h('h3', null, rank(it.priority, it.priority), it.title),
      meta(tag(TYPE_META[it.type].word), tag(`${fmtShort(it.date)}${it.time ? ` ${it.time}` : ''}`), stakeTag(it), it.course ? tag(it.course, 'code') : null),
      h('div', { class: 'progress-row', style: { display: 'flex', flexWrap: 'wrap', gap: '6px 14px', alignItems: 'center' } },
        v.total ? progress(v.done, v.total, { warn: v.status === 'behind' || v.status === 'short', label: `${v.done}/${v.total} sessions` }) : null,
        status)));
}

function dayBlock(d, ctx) {
  const lines = [];
  for (const ev of d.schedule) {
    const end = ev.time ? minToTime(timeToMin(ev.time) + (ev.durationMin || 60)) : null;
    lines.push(h('li', { role: 'button', tabindex: '0', onclick: () => ctx.edit(ev.id) },
      h('span', { class: 't' }, ev.time || 'all day'),
      h('span', { class: 'what' }, ev.type === 'exam' ? h('b', null, 'Exam: ') : ev.type === 'presentation' ? h('b', null, 'Presenting: ') : null, ev.title, end ? h('span', { class: 'muted' }, ` –${end}`) : null),
      ev.course ? h('span', { class: 'code' }, ev.course) : h('span')));
  }
  for (const it of d.due) {
    lines.push(h('li', { role: 'button', tabindex: '0', onclick: () => ctx.edit(it.id) },
      h('span', { class: 't' }, it.time || 'due'),
      h('span', { class: 'what' }, it.priority ? rank(it.priority, it.priority) : null, h('b', null, it.type === 'reading' ? 'Read: ' : 'Due: '), it.title),
      it.course ? h('span', { class: 'code' }, it.course) : h('span')));
  }
  for (const st of d.starts) {
    lines.push(h('li', { class: 'start', role: 'button', tabindex: '0', onclick: () => ctx.edit(st.id) },
      h('span', { class: 't' }, 'start'), h('span', { class: 'what' }, `Start ${st.title}`), h('span')));
  }
  for (const sd of d.study) {
    lines.push(h('li', { class: 'study', role: 'button', tabindex: '0', onclick: () => ctx.edit(sd.item.id) },
      h('span', { class: 't' }, fmtMin(sd.minutes)),
      h('span', { class: 'what' }, `Study: ${sd.item.title}${sd.count > 1 ? ` ×${sd.count}` : ''}`),
      h('span')));
  }
  const budget = ctx.s.settings.perDayMin;
  const wd = weekday(d.date);
  return h('section', { class: `lday${d.date === ctx.today ? ' today' : ''}`, id: `d-${d.date}` },
    h('div', { class: 'date' }, h('span', null, d.date === ctx.today ? 'Today' : WD[wd]), h('b', null, String(Number(d.date.slice(8))))),
    h('div', { class: 'min0' },
      lines.length ? h('ul', null, lines) : h('p', { class: 'free' }, 'Free'),
      d.load ? h('div', { class: 'load' },
        h('div', { class: `bar${d.over ? ' warn' : ''}`, style: { '--p': String(Math.min(100, Math.round((d.load / budget) * 100))) } }, h('i')),
        h('span', null, `${fmtMin(d.load)} of ${fmtMin(budget)}`)) : null));
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
  const load = days.reduce((a, d) => a + d.load, 0);
  return h('div', { class: 'view radar' },
    band('Radar',
      h('div', { class: 'band-top' },
        h('div', { class: 'min0' },
          h('h1', { class: 'display' }, `Next ${horizon} days`),
          h('p', { class: 'sub' }, h('b', null, `${dueCount} due`), ` · ${exams} exam${exams === 1 ? '' : 's'} · ${fmtMin(load)} of study planned`)),
        segmented([[14, '14 days'], [30, '30 days']], horizon, (n) => { ctx.ui.radarDays = n; ctx.refresh(); }, { ariaLabel: 'Range' })),
      chart(days, ctx)),
    h('div', { class: 'col page' },
      missed.length ? h('div', { class: 'banner alert' },
        h('span', { class: 'bi' }, icon('alert')),
        h('span', null, h('b', null, 'Behind on study sessions'), h('span', null, `${missed.map((m) => m.item.title).join(', ')}. ${TIPS.missed}`)),
        h('button', { class: 'btn sm', type: 'button', onclick: ctx.act.replanMissed }, 'Re-plan')) : null,
      over ? h('div', { class: 'banner alert' },
        h('span', { class: 'bi' }, icon('stack')),
        h('span', null, h('b', null, `${over} day${over > 1 ? 's' : ''} over your ${fmtMin(s.settings.perDayMin)} budget`), h('span', null, 'Balance re-spreads everything so A’s get first claim on each day.')),
        h('button', { class: 'btn sm primary', type: 'button', onclick: ctx.act.balance }, 'Balance my plan')) : null,
      h('section', { class: 'part' },
        sec('The vital few', { count: vital.length, note: 'A and B work in the next 6 weeks' }),
        vital.length ? h('ul', { class: 'vital-list' }, vital.map((v) => vitalCard(v, ctx)))
          : h('p', { class: 'empty' }, 'Exams, presentations, deadlines and readings you’ve lettered A or B show up here with their study progress.')),
      h('section', { class: 'part' },
        sec('Day by day'),
        h('div', { class: 'card' }, h('div', { class: 'ledger' }, days.map((d) => dayBlock(d, ctx))))),
      over ? null : h('div', { class: 'btn-row' }, h('button', { class: 'btn quiet', type: 'button', onclick: ctx.act.balance }, icon('stack'), 'Balance my plan'))));
}
