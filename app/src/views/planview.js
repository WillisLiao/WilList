import { h, svg, icon, rank, sec, fmtMin, band, hand, segmented, TYPE_META } from '../ui.js';
import { addDays, diffDays, fmtShort, fmtInDays, relDay } from '../dates.js';
import { dayRows, unsorted, scheduleOn, importantNotUrgent, isOpen, occursOn } from '../agenda.js';
import { weekStats, calibrations } from '../insights.js';
import { TIPS } from '../coach.js';
import { rowEl, timetable, itemMeta, emptyNote, openSorter } from '../components.js';

function moon() {
  return svg('svg', { class: 'moon', viewBox: '0 0 56 56', 'aria-hidden': 'true' },
    svg('path', { d: 'M41 37.5A18.5 18.5 0 1 1 21.5 8.5a14.5 14.5 0 0 0 19.5 29z' }));
}

// A few fixed stars: the same sky every night.
const STARS = [[62, 10], [70, 46], [78, 22], [86, 60], [93, 14], [97, 40], [74, 78], [90, 86], [58, 88], [83, 36]];
function stars() {
  return h('div', { class: 'stars', 'aria-hidden': 'true' }, STARS.map(([x, y], i) => h('i', { style: { left: `${x}%`, top: `${y}%`, opacity: String(0.25 + (i % 4) * 0.15) } })));
}

function step(title, note, done, ...body) {
  return h('li', { class: done ? 'done' : null },
    h('div', { class: 'step-body' }, h('h3', null, title, note ? h('small', null, note) : null), body));
}

function tonight(ctx) {
  const { s, today } = ctx;
  const tomorrow = addDays(today, 1);
  const tray = unsorted(s.items, today);
  const rows = dayRows(s.items, tomorrow, today);
  const events = scheduleOn(s.items, tomorrow);
  const soon = s.items.filter((it) => isOpen(it, today) && it.date && !it.recur && it.type !== 'event' &&
    diffDays(tomorrow, it.date) >= 0 && diffDays(tomorrow, it.date) <= 3)
    .sort((a, b) => a.date.localeCompare(b.date));
  const planned = s.meta.lastPlanned === today;
  const aRows = rows.filter((r) => r.priority === 'A');
  const ta = h('textarea', {
    id: 'dump', class: 'ruled', rows: '4', 'aria-label': 'Everything on your mind, one per line',
    placeholder: 'One thing per line…', value: ctx.ui.dump || '', oninput: (e) => { ctx.ui.dump = e.target.value; },
  });
  return h('ol', { class: 'steps' },
    step('Empty your head', 'think on paper', false,
      h('p', { class: 'lede' }, 'Homework, emails, errands, worries. One per line, written the way you’d say it.'),
      ta,
      h('div', { class: 'btn-row' }, h('button', { class: 'btn primary', type: 'button', onclick: () => {
        const lines = (ctx.ui.dump || '').split('\n').map((l) => l.trim()).filter(Boolean);
        if (!lines.length) return;
        ctx.ui.dump = '';
        ctx.act.addMany(lines);
      } }, icon('plus'), 'Add every line'))),
    step('Fill in a letter', null, !tray.length,
      tray.length ? h('button', { class: 'banner sort', type: 'button', onclick: () => openSorter(ctx) },
        h('span', { class: 'bi' }, icon('sort')),
        h('span', null, h('b', null, `${tray.length} without a letter`), h('span', null, TIPS.consequences)),
        h('span', { class: 'btn sm primary' }, 'Sort'))
        : emptyNote('Every item has a letter.')),
    step(`Look at tomorrow`, fmtShort(tomorrow), false,
      events.length ? h('div', { class: 'card' }, timetable(events, ctx, { isToday: false })) : emptyNote('No classes or meetings tomorrow.'),
      soon.length ? h('ul', { class: 'lines' }, soon.map((it) => h('li', null,
        it.priority ? rank(it.priority, it.priority) : null,
        h('span', { class: 'grow', role: 'button', tabindex: '0', onclick: () => ctx.edit(it.id) }, it.title),
        itemMeta(it, tomorrow)))) : null),
    step('Number your A’s', aRows.length > 5 ? TIPS.tooManyA(aRows.length) : 'worst consequence first', false,
      rows.length
        ? h('ul', { class: 'rows card' }, rows.map((r) => rowEl(r, { ...ctx, today: tomorrow, act: { ...ctx.act, move: (key, dir) => ctx.act.move(key, dir, rows) } }, { startable: false })))
        : emptyNote('Nothing lettered for tomorrow yet.')),
    step('Lock it in', null, planned,
      planned
        ? h('div', { class: 'locked' }, moon(), h('div', null, h('b', null, 'Locked in for tomorrow.'), h('div', null, hand('sleep on it.'))))
        : h('div', { class: 'lock' },
          h('button', { class: 'btn primary', type: 'button', onclick: ctx.act.lockPlan }, icon('plan'), 'Lock in tomorrow'),
          h('p', { class: 'foot' }, TIPS.planTonight))));
}

function week(ctx) {
  const { s, today } = ctx;
  const stats = weekStats(s, today);
  const cal = calibrations(s.log, s.settings.calib);
  const end = addDays(today, 7);
  let classes = 0;
  for (let k = 0; k < 7; k++) classes += s.items.filter((it) => it.type === 'event' && occursOn(it, addDays(today, k))).length;
  const big = s.items.filter((it) => isOpen(it, today) && !it.recur && it.type !== 'event' && it.date &&
    diffDays(today, it.date) >= 0 && diffDays(it.date, end) > 0).sort((a, b) => a.date.localeCompare(b.date));
  const inu = importantNotUrgent(s.items, today);
  const stale = s.items.filter((it) => ['C', 'D', 'E'].includes(it.priority) && !it.done && it.type !== 'event' &&
    it.createdAt && diffDays(it.createdAt, today) >= 14);
  return [
    h('section', { class: 'part' },
      sec('The last 7 days'),
      h('div', { class: 'stats' },
        h('div', { class: 'stat' }, h('b', null, fmtMin(stats.focusMin)), h('span', null, 'focused')),
        h('div', { class: 'stat' }, h('b', null, String(stats.aDone)), h('span', null, 'A’s done')),
        h('div', { class: 'stat' }, h('b', null, `${stats.aFirstDays}/${stats.activeDays || 0}`), h('span', null, 'days with an A first')),
        h('div', { class: 'stat' }, h('b', null, String(stats.done)), h('span', null, 'things done'))),
      cal.length ? h('div', { class: 'card pad' },
        sec('Your real pace', { level: 'h3' }),
        h('ul', { class: 'lines' }, cal.map((c) => h('li', null,
          h('span', { class: 'grow' }, `${c.label} takes you about ${c.ratio}× the plan (${c.n} focus sessions).`),
          h('button', { class: 'btn sm', type: 'button', onclick: () => ctx.act.setCalib(c.type, c.ratio) }, `Plan ${c.ratio}× from now on`)))))
        : h('p', { class: 'foot' }, 'Use Start (focus mode) on study sessions. After three finished sessions of a kind, WilList shows how long they really take compared with the plan.')),
    h('section', { class: 'part' },
      sec('The next 7 days', { note: `${classes} classes & meetings` }),
      big.length ? h('ul', { class: 'lines card' }, big.map((it) => h('li', null,
        it.priority ? rank(it.priority, it.priority) : null,
        h('span', { class: 'grow', role: 'button', tabindex: '0', onclick: () => ctx.edit(it.id) }, it.title),
        h('span', { class: 'muted small' }, `${TYPE_META[it.type].word} · ${relDay(it.date, today)}${it.time ? ` ${it.time}` : ''}`)))) : emptyNote('Nothing dated this week.')),
    h('section', { class: 'part' },
      sec('Important, not urgent', { note: 'A’s 4–30 days out' }),
      h('p', { class: 'lede' }, 'Urgent things are seldom important; important things are seldom urgent. Get ahead on these now.'),
      inu.length ? h('ul', { class: 'lines card' }, inu.map((it) => {
        const first = (it.sessions || []).find((x) => !x.done);
        const canPull = first && diffDays(today, first.date) > 0;
        return h('li', null,
          h('span', { class: 'grow', role: 'button', tabindex: '0', onclick: () => ctx.edit(it.id) }, it.title),
          h('span', { class: 'muted small' }, fmtInDays(it.date, today)),
          canPull ? h('button', { class: 'btn sm', type: 'button', onclick: () => ctx.act.pullForward(it.id) }, 'Do a session today') : null);
      })) : emptyNote('Nothing important is waiting quietly.')),
    h('section', { class: 'part' },
      sec('Goals', { count: s.goals.length }),
      s.goals.length ? h('ul', { class: 'lines card' }, s.goals.map((g) => {
        const next = s.items.find((it) => it.goalId === g.id && !it.done);
        return h('li', null,
          h('span', { class: 'grow', role: 'button', tabindex: '0', onclick: () => ctx.editGoal(g.id) }, g.title),
          next ? h('span', { class: 'muted small' }, `Next: ${next.title}`) : h('button', { class: 'btn sm', type: 'button', onclick: () => ctx.edit(null, { goalId: g.id, type: 'task', priority: 'A' }) }, 'Add next step'));
      })) : h('p', { class: 'empty' }, 'No written goals yet. ', h('button', { class: 'link', type: 'button', onclick: () => ctx.go('goals') }, 'Write your first one.'))),
    stale.length ? h('section', { class: 'part' },
      sec('Still worth it?', { count: stale.length }),
      h('p', { class: 'lede' }, `${TIPS.eliminate} These C, D and E items have waited two weeks or more.`),
      h('ul', { class: 'lines card' }, stale.map((it) => h('li', null,
        rank(it.priority, it.priority), h('span', { class: 'grow' }, it.title),
        h('button', { class: 'btn sm', type: 'button', onclick: () => ctx.act.keep(it.id) }, 'Keep'),
        h('button', { class: 'btn sm danger', type: 'button', onclick: () => ctx.act.remove(it.id) }, 'Drop'))))) : null,
    h('section', { class: 'card pad' },
      sec('Balance', { level: 'h3' }),
      h('p', { class: 'muted' }, 'When will you see the people you care about this week, sleep enough, and move? Personal goals are the reason for everything else.')),
  ];
}

export function renderPlan(ctx) {
  const tab = ctx.ui.planTab || 'tonight';
  const set = (t) => { ctx.ui.planTab = t; ctx.refresh(); };
  return h('div', { class: 'view plan' },
    band('Plan',
      stars(),
      h('div', { class: 'band-top nowrap' },
        h('div', { class: 'min0' },
          h('h1', { class: 'display' }, tab === 'tonight' ? 'Plan tomorrow' : 'Weekly review'),
          h('p', { class: 'sub' }, tab === 'tonight' ? 'Two minutes tonight. Failing to plan is planning to fail.' : 'Ten minutes on Sunday: look back, look ahead, clean up.')),
        moon()),
      segmented([['tonight', 'Tonight'], ['week', 'This week']], tab, set, { ariaLabel: 'Plan', tabs: true })),
    h('div', { class: 'col page' }, tab === 'tonight' ? tonight(ctx) : week(ctx)));
}
