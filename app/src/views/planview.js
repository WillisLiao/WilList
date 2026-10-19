import { h, icon, courseChip } from '../ui.js';
import { addDays, diffDays, fmtShort, fmtTime, fmtInDays, fmtRelDay } from '../dates.js';
import { dayRows, unsorted, scheduleOn, importantNotUrgent, isOpen, occursOn } from '../agenda.js';
import { TIPS } from '../coach.js';
import { rowEl, trayEl, scheduleEl, typeIcon, dueChip, emptyNote } from '../components.js';

function step(n, title, body, note) {
  return h('section', { class: 'card step' },
    h('div', { class: 'card-head' }, h('span', { class: 'step-n' }, String(n)), h('h3', null, title)),
    note ? h('p', { class: 'group-note' }, note) : null,
    body);
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
  const ta = h('textarea', {
    id: 'dump', rows: '4', placeholder: 'One thing per line…\nEmail TA about regrade\nHistory essay due nov 3\nBuy printer ink',
    value: ctx.ui.dump || '', oninput: (e) => { ctx.ui.dump = e.target.value; },
  });
  const planned = s.meta.lastPlanned === today;
  const aRows = rows.filter((r) => r.priority === 'A');
  return [
    step(1, 'Empty your head', h('div', null, ta,
      h('div', { class: 'btn-row' }, h('button', { class: 'btn primary', onclick: () => {
        const lines = (ctx.ui.dump || '').split('\n').map((l) => l.trim()).filter(Boolean);
        if (!lines.length) return;
        ctx.ui.dump = '';
        ctx.act.addMany(lines);
      } }, icon('plus'), 'Add all'))),
    'Anything on your mind: homework, emails, errands, worries. Think on paper.'),
    step(2, 'Give everything a letter', tray.length ? trayEl(tray, ctx) : emptyNote('Everything has a letter. ✓'), null),
    step(3, 'Tomorrow at a glance', h('div', null,
      scheduleEl(events, ctx, { title: `Schedule · ${fmtShort(tomorrow)}`, isToday: false }) || emptyNote('No classes or meetings tomorrow.'),
      soon.length ? h('div', { class: 'soon' }, h('h4', null, 'Due in the next few days'),
        h('ul', { class: 'mini' }, soon.map((it) => h('li', { role: 'button', tabindex: '0', onclick: () => ctx.edit(it.id) },
          typeIcon(it.type), h('span', null, it.title), dueChip(it, tomorrow), courseChip(it.course))))) : null), null),
    step(4, 'Number your A’s for tomorrow', rows.length
      ? h('ul', { class: 'rows' }, rows.map((r) => rowEl(r, { ...ctx, today: tomorrow, act: { ...ctx.act, move: (key, dir) => ctx.act.move(key, dir, rows) } }, { startable: false })))
      : emptyNote('Nothing lettered for tomorrow yet.'),
    aRows.length ? `Put the one with the worst consequences first. That is A1, and you do it before anything else.${aRows.length > 5 ? ` ${TIPS.tooManyA(aRows.length)}` : ''}` : 'Use the arrows to put tomorrow’s most important item at the top.'),
    h('div', { class: 'btn-row center' },
      h('button', { class: `btn primary big${planned ? ' done' : ''}`, onclick: ctx.act.lockPlan },
        icon('check'), planned ? 'Planned. Sleep on it.' : 'Lock in tomorrow')),
    h('p', { class: 'foot-tip' }, TIPS.planTonight),
  ];
}

function week(ctx) {
  const { s, today } = ctx;
  const end = addDays(today, 7);
  const inWeek = (d) => d && diffDays(today, d) >= 0 && diffDays(d, end) > 0;
  let classes = 0;
  for (let k = 0; k < 7; k++) classes += s.items.filter((it) => it.type === 'event' && occursOn(it, addDays(today, k))).length;
  const big = s.items.filter((it) => isOpen(it, today) && !it.recur && it.type !== 'event' && inWeek(it.date))
    .sort((a, b) => a.date.localeCompare(b.date));
  const count = (t) => big.filter((it) => it.type === t).length;
  const inu = importantNotUrgent(s.items, today);
  const stale = s.items.filter((it) => ['C', 'D', 'E'].includes(it.priority) && !it.done && it.type !== 'event' &&
    it.createdAt && diffDays(it.createdAt, today) >= 14);
  return [
    h('section', { class: 'card' },
      h('div', { class: 'card-head' }, h('h3', null, 'The next 7 days')),
      h('div', { class: 'stats' },
        h('div', null, h('b', null, String(classes)), h('span', null, 'classes & meetings')),
        h('div', null, h('b', null, String(count('exam'))), h('span', null, 'exams')),
        h('div', null, h('b', null, String(count('presentation'))), h('span', null, 'presentations')),
        h('div', null, h('b', null, String(count('deadline') + count('reading'))), h('span', null, 'deadlines'))),
      big.length ? h('ul', { class: 'mini' }, big.map((it) => h('li', { role: 'button', tabindex: '0', onclick: () => ctx.edit(it.id) },
        it.priority ? h('span', { class: `badge l-${it.priority}` }, it.priority) : h('span', { class: 'badge' }, '?'),
        typeIcon(it.type), h('span', null, it.title),
        h('span', { class: 'chip' }, `${fmtRelDay(it.date, today)}${it.time ? ` ${fmtTime(it.time)}` : ''}`)))) : null),
    h('section', { class: 'card' },
      h('div', { class: 'card-head' }, h('h3', null, 'Important, not urgent')),
      h('p', { class: 'group-note' }, 'Urgent things are seldom important; important things are seldom urgent. These are your A’s 4–30 days out. Get ahead on them now.'),
      inu.length ? h('ul', { class: 'mini' }, inu.map((it) => {
        const first = (it.sessions || []).find((x) => !x.done);
        const canPull = first && diffDays(today, first.date) > 0;
        return h('li', null,
          typeIcon(it.type),
          h('span', { role: 'button', tabindex: '0', onclick: () => ctx.edit(it.id) }, it.title),
          h('span', { class: 'chip' }, fmtInDays(it.date, today)),
          canPull ? h('button', { class: 'btn sm', onclick: () => ctx.act.pullForward(it.id) }, 'Do a session today') : null);
      })) : emptyNote('Nothing important is waiting quietly. Nice.')),
    h('section', { class: 'card' },
      h('div', { class: 'card-head' }, h('h3', null, 'Goals check')),
      s.goals.length ? h('ul', { class: 'mini' }, s.goals.map((g) => {
        const next = s.items.find((it) => it.goalId === g.id && !it.done);
        return h('li', null, icon('target'), h('span', { role: 'button', tabindex: '0', onclick: () => ctx.editGoal(g.id) }, g.title),
          next ? h('span', { class: 'chip' }, `Next: ${next.title}`)
            : h('button', { class: 'btn sm', onclick: () => ctx.edit(null, { goalId: g.id, type: 'task', priority: 'A' }) }, icon('plus'), 'Next step'));
      })) : h('p', { class: 'empty-note' }, 'No written goals yet. ', h('button', { class: 'link', onclick: () => ctx.go('goals') }, 'Write your first one.'))),
    stale.length ? h('section', { class: 'card' },
      h('div', { class: 'card-head' }, h('h3', null, 'Still worth it?')),
      h('p', { class: 'group-note' }, `${TIPS.eliminate} These C/D/E items have been sitting for two weeks or more.`),
      h('ul', { class: 'mini' }, stale.map((it) => h('li', null,
        h('span', { class: `badge l-${it.priority}` }, it.priority), h('span', null, it.title),
        h('button', { class: 'btn sm', onclick: () => ctx.act.keep(it.id) }, 'Keep'),
        h('button', { class: 'btn sm', onclick: () => ctx.act.remove(it.id) }, icon('trash'), 'Drop'))))) : null,
    h('section', { class: 'card calm' },
      h('h3', null, 'Balance'),
      h('p', null, 'Before you lock in the week: when will you see the people you care about, sleep enough and move your body? Personal goals are the “why” behind everything else.')),
  ];
}

export function renderPlan(ctx) {
  const tab = ctx.ui.planTab || 'tonight';
  const set = (t) => { ctx.ui.planTab = t; ctx.refresh(); };
  return h('div', { class: 'view plan' },
    h('header', { class: 'view-head' },
      h('h1', null, 'Plan'),
      h('p', { class: 'lede' }, 'Failing to plan is planning to fail. Two minutes tonight, ten minutes on Sunday.')),
    h('div', { class: 'tabs', role: 'tablist' },
      h('button', { role: 'tab', 'aria-selected': String(tab === 'tonight'), class: tab === 'tonight' ? 'on' : '', onclick: () => set('tonight') }, 'Plan tomorrow'),
      h('button', { role: 'tab', 'aria-selected': String(tab === 'week'), class: tab === 'week' ? 'on' : '', onclick: () => set('week') }, 'Weekly review')),
    tab === 'tonight' ? tonight(ctx) : week(ctx));
}
